//
//  SupabaseDeviceTokenService.swift
//  LastPlace
//
//  Concrete DeviceTokenService backed by the `device_tokens` table from the
//  `add_device_tokens_and_item_update_notify_trigger` migration.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session, same caveat as the other Supabase-backed services. `onConflict:`
//  on `.upsert(_:onConflict:)` is the documented postgrest-swift shape for
//  resolving on a column other than the primary key -- needed here since
//  `device_tokens` is conflict-checked on `token` (unique), not `id` (which
//  this never sends, letting Postgres generate a fresh one only on first
//  insert). Confirm this compiles as written before trusting it.
//

import Foundation
import Supabase

final class SupabaseDeviceTokenService: DeviceTokenService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func registerToken(_ token: String, platform: String) async throws {
        guard let userID = await currentUserID() else { throw DeviceTokenError.notAuthenticated }
        do {
            try await client
                .from("device_tokens")
                .upsert(
                    DeviceTokenRow(userID: userID, token: token, platform: platform),
                    onConflict: "token"
                )
                .execute()
        } catch {
            throw DeviceTokenError.registrationFailed(underlying: error.localizedDescription)
        }
    }

    func unregisterToken(_ token: String) async throws {
        do {
            try await client
                .from("device_tokens")
                .delete()
                .eq("token", value: token)
                .execute()
        } catch {
            throw DeviceTokenError.registrationFailed(underlying: error.localizedDescription)
        }
    }

    private func currentUserID() async -> UUID? {
        (try? await client.auth.session)?.user.id
    }
}

private struct DeviceTokenRow: Encodable, Sendable {
    let userID: UUID
    let token: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
        case platform
    }
}
