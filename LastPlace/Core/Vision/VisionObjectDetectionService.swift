//
//  VisionObjectDetectionService.swift
//  LastPlace
//
//  Default detector backed by `VNClassifyImageRequest` — Apple's built-in
//  ~1000-class image classifier. No bundled ML model. Confidence and label
//  come from Vision; bounding box is the whole image because classification is
//  frame-level, not localized.
//

import Foundation
@preconcurrency import Vision
import CoreGraphics

struct VisionObjectDetectionService: ObjectDetectionService {
    private let maxResults: Int

    init(maxResults: Int = 5) {
        self.maxResults = maxResults
    }

    func detect(in imageData: Data, minimumConfidence: Double) async throws -> [DetectedObject] {
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

                let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
                let filtered = observations
                    .filter { Double($0.confidence) >= minimumConfidence }
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(maxResults)
                    .map { observation in
                        DetectedObject(
                            label: observation.identifier.humanizedLabel,
                            confidence: Double(observation.confidence),
                            boundingBox: fullFrame
                        )
                    }
                continuation.resume(returning: Array(filtered))
            }

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            do {
                try handler.perform([request])
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
