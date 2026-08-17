//
//  VisionObjectDetectionService.swift
//  LastPlace
//
//  Default detector backed by `VNClassifyImageRequest` — Apple's built-in
//  ~1000-class image classifier. No bundled ML model.
//
//  `VNClassifyImageRequest` alone labels the *whole frame* — background,
//  context, whatever's most visually dominant — not specifically the item
//  someone framed up in the photo, which produced plausible-but-wrong
//  labels (e.g. a couch's actual detail photographed close-up coming back
//  as a broad room/furniture label). To fix that without a custom-trained
//  object detector, this first runs
//  `VNGenerateObjectnessBasedSaliencyImageRequest` (Vision's built-in
//  "what's the main foreground object here" detector) to find the most
//  prominent object's bounding box, crops to just that region, and
//  classifies the crop instead of the full image. Falls back to
//  classifying the whole frame if saliency finds nothing or the image
//  can't be decoded into a `CGImage`.
//

import CoreGraphics
import Foundation
import ImageIO
@preconcurrency import Vision

struct VisionObjectDetectionService: ObjectDetectionService {
    private let maxResults: Int
    /// Extra margin added around the detected salient region before
    /// cropping, so the object isn't cut off flush at its edges.
    private let paddingFraction: CGFloat = 0.08

    private static let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)

    init(maxResults: Int = 5) {
        self.maxResults = maxResults
    }

    func detect(in imageData: Data, minimumConfidence: Double) async throws -> [DetectedObject] {
        // Everything below works in a single, already-upright coordinate
        // space -- see `makeOrientedCGImage`. That matters because a
        // `CGImage` decoded straight from JPEG bytes is the raw sensor
        // buffer with EXIF orientation *not* applied, so without this every
        // request ran against a sideways image and returned confident
        // nonsense. Normalizing once up front is also why the saliency box
        // and the crop below can share coordinates without any transform.
        guard let cgImage = Self.makeOrientedCGImage(from: imageData) else {
            // `VNImageRequestHandler(data:)` reads EXIF itself, so the
            // fallback path is already orientation-correct.
            return try await classify(cgImage: nil, imageData: imageData, boundingBox: Self.fullFrame, minimumConfidence: minimumConfidence)
        }

        if let salientBox = try? await detectSalientBoundingBox(in: cgImage),
           let cropped = crop(cgImage, to: salientBox) {
            return try await classify(cgImage: cropped, imageData: nil, boundingBox: salientBox, minimumConfidence: minimumConfidence)
        }

        return try await classify(cgImage: cgImage, imageData: nil, boundingBox: Self.fullFrame, minimumConfidence: minimumConfidence)
    }

    // MARK: - Saliency (find the main object before classifying it)

    private func detectSalientBoundingBox(in cgImage: CGImage) async throws -> CGRect? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let observation = request.results?.first as? VNSaliencyImageObservation,
                    let salientObjects = observation.salientObjects,
                    let best = salientObjects.max(by: { $0.confidence < $1.confidence })
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: best.boundingBox)
            }
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// `box` is Vision-normalized (unit square, origin bottom-left). Pads
    /// it, clamps to the image bounds, and converts to top-left-origin
    /// pixel space for `CGImage.cropping(to:)`.
    private func crop(_ cgImage: CGImage, to box: CGRect) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let padded = CGRect(
            x: box.minX - box.width * paddingFraction,
            y: box.minY - box.height * paddingFraction,
            width: box.width * (1 + 2 * paddingFraction),
            height: box.height * (1 + 2 * paddingFraction)
        ).intersection(Self.fullFrame)

        guard !padded.isNull, padded.width > 0, padded.height > 0 else { return nil }

        let pixelRect = CGRect(
            x: padded.minX * width,
            y: (1 - padded.maxY) * height,
            width: padded.width * width,
            height: padded.height * height
        ).integral

        return cgImage.cropping(to: pixelRect)
    }

    /// Decodes to a `CGImage` with the file's EXIF orientation already
    /// baked in, so the returned pixels are visually upright and can be
    /// treated as `.up` everywhere downstream.
    ///
    /// Uses the thumbnail API purely because
    /// `kCGImageSourceCreateThumbnailWithTransform` is what applies the
    /// orientation transform -- `CGImageSourceCreateImageAtIndex` has no
    /// equivalent option and hands back the raw, unrotated buffer. Capping
    /// the long edge is a welcome side effect: a full 12MP frame is far more
    /// than Vision's classifier needs, and downsizing makes both the
    /// saliency pass and the classification meaningfully faster.
    private static func makeOrientedCGImage(from data: Data, maxPixelSize: Int = 2048) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: - Classification

    private func classify(
        cgImage: CGImage?,
        imageData: Data?,
        boundingBox: CGRect,
        minimumConfidence: Double
    ) async throws -> [DetectedObject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let filtered = observations
                    .filter { Double($0.confidence) >= minimumConfidence }
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(maxResults)
                    .map { observation in
                        DetectedObject(
                            label: observation.identifier.humanizedLabel,
                            confidence: Double(observation.confidence),
                            boundingBox: boundingBox
                        )
                    }
                continuation.resume(returning: Array(filtered))
            }

            do {
                if let cgImage {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } else if let imageData {
                    try VNImageRequestHandler(data: imageData, options: [:]).perform([request])
                } else {
                    continuation.resume(returning: [])
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private extension String {
    /// Vision returns machine identifiers like `laptop_computer` — reshape to a
    /// display-ready title so the review UI doesn't leak underscores.
    var humanizedLabel: String {
        replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
