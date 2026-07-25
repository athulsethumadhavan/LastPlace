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

final class SupabaseAIItemIdentificationService: AIItemIdentificationService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func identifyItem(in imageData: Data) async throws -> AIItemIdentification {
        guard (try? await client.auth.session) != nil else {
            throw AIItemIdentificationError.notAuthenticated
        }
        do {
            let response: IdentifyItemResponse = try await client.functions.invoke(
                "identify-item",
                options: FunctionInvokeOptions(
                    body: IdentifyItemRequest(
                        imageBase64: imageData.base64EncodedString(),
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
