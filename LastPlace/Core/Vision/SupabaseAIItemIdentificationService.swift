//
//  SupabaseAIItemIdentificationService.swift
//  LastPlace
//
//  Calls the `identify-item` Supabase Edge Function, which holds the
//  Anthropic API key server-side and forwards the photo to a vision-capable
//  Claude model.
//
//  Uses `URLSession` directly rather than `client.functions.invoke`. That
//  isn't a style preference: with `invoke` every call failed as
//  "The request timed out" and *nothing* appeared in the Edge Function logs
//  -- so there was no way to tell whether the request was malformed, too
//  large, rejected at the gateway, or never sent at all. Hand-rolling the
//  request buys three things that matter more here than the convenience:
//
//    * an explicit `timeoutInterval`, instead of URLSession's 60s default
//      (a minute of the user waiting to find out something failed),
//    * visibility of the exact status code and response body, which is what
//      turns "timed out" into an actionable error,
//    * a logged payload size, so an oversized body can be ruled in or out
//      immediately rather than inferred.
//
//  Auth is the same as `invoke` would send: the user's access token on
//  `Authorization`, and the publishable key on `apikey`. Supabase's new
//  key format cannot be used as a Bearer token, which is also why
//  `identify-item` runs with `verify_jwt: false` and authorises in code.
//

import Foundation
import Supabase
import UIKit

final class SupabaseAIItemIdentificationService: AIItemIdentificationService {
    private let client: SupabaseClient
    private let session: URLSession
    private let logger: AppLogger

    /// Anthropic downscales any image whose long edge exceeds 1568px before
    /// processing it, so sending anything larger is wasted upload time that
    /// cannot improve recognition.
    private static let maxLongEdge: CGFloat = 1568
    private static let jpegQuality: CGFloat = 0.8

    /// Generous enough for a cold Edge Function start plus vision
    /// inference (typically 2-4s), short enough that a genuine failure
    /// surfaces quickly. The old 60s default meant a broken call blocked
    /// the scan UI for a minute.
    private static let requestTimeout: TimeInterval = 25

    init(
        client: SupabaseClient = SupabaseClientProvider.shared,
        session: URLSession = .shared,
        logger: AppLogger = OSAppLogger()
    ) {
        self.client = client
        self.session = session
        self.logger = logger
    }

    func identifyItem(in imageData: Data) async throws -> AIItemIdentification {
        guard let accessToken = (try? await client.auth.session)?.accessToken else {
            throw AIItemIdentificationError.notAuthenticated
        }

        // `AVFoundationCameraCaptureService` captures at full sensor
        // resolution, so a raw capture is a ~12MP JPEG -- several MB, and a
        // third larger again once base64-encoded into JSON. This also bakes
        // in EXIF orientation, so the model sees the photo the right way up.
        let payload = Self.normalizedJPEG(from: imageData) ?? imageData
        let base64 = payload.base64EncodedString()
        logger.log(
            "identify-item request: \(payload.count / 1024)KB image, \(base64.count / 1024)KB encoded",
            category: "scan"
        )

        var request = URLRequest(
            url: SupabaseConfig.projectURL.appendingPathComponent("functions/v1/identify-item"),
            timeoutInterval: Self.requestTimeout
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(
            IdentifyItemRequest(imageBase64: base64, mediaType: "image/jpeg")
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIItemIdentificationError.requestFailed(underlying: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIItemIdentificationError.requestFailed(underlying: "Malformed response")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Include the body: the function returns a JSON `error` field
            // naming the actual cause (missing API key, bad auth, Anthropic
            // rejection), which is far more useful than the status alone.
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIItemIdentificationError.requestFailed(
                underlying: "HTTP \(http.statusCode): \(body.prefix(300))"
            )
        }

        do {
            let decoded = try JSONDecoder().decode(IdentifyItemResponse.self, from: data)
            return AIItemIdentification(
                name: decoded.name,
                category: ItemCategory(rawValue: decoded.category) ?? .other,
                confidence: min(max(decoded.confidence, 0), 1)
            )
        } catch {
            throw AIItemIdentificationError.requestFailed(
                underlying: "Unreadable response: \(error.localizedDescription)"
            )
        }
    }

    /// Re-encodes `imageData` upright, with its long edge capped at
    /// `maxLongEdge`.
    ///
    /// Runs even when no resize is needed, because the orientation half
    /// matters on its own: `UIImage(data:)` reads the EXIF orientation and
    /// `draw(in:)` bakes it into the pixels, so the model receives an
    /// upright image rather than having to honour EXIF itself.
    ///
    /// Returns `nil` only if the bytes can't be decoded, in which case the
    /// caller sends the original -- this should never block identification.
    private static func normalizedJPEG(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let longEdge = max(image.size.width, image.size.height)
        // Never upscale; cap only when bigger than the ceiling.
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
