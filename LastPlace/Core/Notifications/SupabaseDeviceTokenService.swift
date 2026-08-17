//
//  SupabaseDeviceTokenService.swift
//  LastPlace
//
//  Concrete DeviceTokenService backed by the `device_tokens` table from the
//  `add_device_tokens_and_item_update_notify_trigger` migration.
//
//  Registration goes through the `register_device_token` RPC rather than a
//  direct upsert. An FCM token identifies an *install*, not a person, and
//  Firebase hands back the same one when a second account signs in on a
//  device that already registered. A direct upsert conflicts on the unique
//  `token` column, which makes it an UPDATE, which makes RLS evaluate
//  `device_tokens_owner_all`'s USING clause against the row still owned by
//  the *previous* account -- 42501, on every launch, permanently. The
//  device then silently never receives another push. The RPC is
//  SECURITY DEFINER so it can reassign the token, and always keys the row
//  to `auth.uid()` rather than anything the caller supplies.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session, same caveat as the other Supabase-backed services. The
//  `.rpc(_:params:)` shape matches the existing calls in
//  `SupabaseRoomSharingService` / `SupabaseItemGiftingService`.
//

import Foundation
import Supabase

final class SupabaseDeviceTokenService: DeviceTokenService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func registerToken(_ token: String, platform: String) async throws {
        // The RPC raises 42501 on a null `auth.uid()` anyway; checking here
        // first turns "some opaque Postgres error" into the specific case
        // `MainTabView` needs to distinguish -- a token arriving before
        // sign-in is expected, not a failure worth logging.
        guard await isAuthenticated() else { throw DeviceTokenError.notAuthenticated }
        do {
            try await client
                .rpc("register_device_token", params: [
                    "p_token": token,
                    "p_platform": platform
                ])
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

    private func isAuthenticated() async -> Bool {
        (try? await client.auth.session) != nil
    }
}
