//
//  SupabaseAIItemIdentificationService.swift
//  LastPlace
//
//  Calls the `identify-item` Supabase Edge Function, which holds the
//  Anthropic API key server-side and forwards the photo to a vision-
//  capable Claude model. The function requires a valid JWT (verify_jwt),
//  so this never runs for a signed-out install.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session. The `.functions.invoke(_:options:)` call with a typed
//  Encodable body and Decodable response was checked against Supabase's
//  official Swift docs before writing this, but build in Xcode first.
//

import Foundation
import Supabase
import UIKit

final class SupabaseAIItemIdentificationService: AIItemIdentificationService {
    private let client: SupabaseClient

    /// Anthropic downscales any image whose long edge exceeds 1568px before
    /// processing it, so sending anything larger is wasted bytes -- it costs
    /// upload time and request size without improving recognition at all.
    private static let maxLongEdge: CGFloat = 1568
    private static let jpegQuality: CGFloat = 0.8

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func identifyItem(in imageData: Data) async throws -> AIItemIdentification {
        guard (try? await client.auth.session) != nil else {
            throw AIItemIdentificationError.notAuthenticated
        }

        // `AVFoundationCameraCaptureService` captures at full sensor
        // resolution (`sessionPreset = .photo`, no `maxPhotoDimensions`), so
        // a raw capture is a ~12MP JPEG -- several MB, and roughly a third
        // larger again once base64-encoded into a JSON body. Downscaling
        // first cuts the payload by an order of magnitude for free, since
        // the model would have downscaled it server-side anyway.
        let payload = Self.normalizedJPEG(from: imageData) ?? imageData

        do {
            let response: IdentifyItemResponse = try await client.functions.invoke(
                "identify-item",
                options: FunctionInvokeOptions(
                    body: IdentifyItemRequest(
                        imageBase64: payload.base64EncodedString(),
                        mediaType: "image/jpeg"
                    )
                )
            )
            return AIItemIdentification(
                name: response.name,
                category: ItemCategory(rawValue: response.category) ?? .other,
                confidence: min(max(response.confidence, 0), 1)
            )
        } catch {
            throw AIItemIdentificationError.requestFailed(underlying: error.localizedDescription)
        }
    }

    /// Re-encodes `imageData` upright, with its long edge capped at
    /// `maxLongEdge`.
    ///
    /// Does two jobs, and the orientation one is why it runs even when no
    /// resize is needed: `UIImage(data:)` reads the EXIF orientation and
    /// `draw(in:)` bakes it into the pixels, so the model receives an image
    /// the right way up rather than relying on it to honour EXIF itself.
    /// Sending raw camera bytes was producing sideways input and, with it,
    /// confidently wrong names.
    ///
    /// Returns `nil` only if the bytes can't be decoded, in which case the
    /// caller sends the original -- this should never block identification.
    private static func normalizedJPEG(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let longEdge = max(image.size.width, image.size.height)
        // Never upscale; cap only when the image is bigger than the ceiling.
        let scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1
        let targetSize = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        let format = UIGraphicsImageRendererFormat.default()
        // Draw at exactly `targetSize` in pixels. Without this the renderer
        // uses the screen's scale factor and produces a 2x/3x larger image
        // than asked for, defeating the point of resizing.
        format.scale = 1
        format.opaque = true

        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}

private struct IdentifyItemRequest: Encodable {
    let imageBase64: String
    let mediaType: String
}

private struct IdentifyItemResponse: Decodable {
    let name: String
    let category: String
    let confidence: Double
}
