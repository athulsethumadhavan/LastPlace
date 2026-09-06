//
//  SupabaseEntitlementService.swift
//  LastPlace
//
//  Concrete EntitlementService backed by the `entitlements` table and the
//  `has_active_entitlement` / `remaining_item_slots` functions from the
//  `add_entitlements_and_free_tier_limits` and
//  `enforce_free_tier_item_limit` migrations.
//
//  Read-only by construction: there is no code path here that writes to
//  `entitlements`, and no RLS policy that would let one succeed.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session. The `.rpc(_:params:)` and no-argument `.rpc(_:)` shapes match
//  the existing calls in `SupabaseRoomSharingService` and
//  `SupabaseItemGiftingService`.
//

import Foundation
import Supabase

final class SupabaseEntitlementService: EntitlementService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func status() async throws -> EntitlementStatus {
        guard let userID = await currentUserID() else {
            throw EntitlementError.notAuthenticated
        }

        do {
            // Both server-side, so the limit and the counting rule live in
            // one place. Asking the database "how many may I still add"
            // rather than counting local SwiftData rows also means an item
            // created on another device is accounted for.
            async let premiumTask: Bool = client
                .rpc("has_active_entitlement", params: ["p_user_id": userID.uuidString])
                .execute()
                .value
            async let slotsTask: Int? = client
                .rpc("remaining_item_slots")
                .execute()
                .value

            let (isPremium, slots) = try await (premiumTask, slotsTask)

            // `remaining_item_slots` returns null for entitled accounts, so
            // the two answers agree by construction. Normalised anyway: if
            // they ever disagree, unlimited-for-a-free-account is the
            // failure that costs money.
            return EntitlementStatus(
                isPremium: isPremium,
                remainingItemSlots: isPremium ? nil : (slots ?? 0)
            )
        } catch {
            throw EntitlementError.lookupFailed(underlying: error.localizedDescription)
        }
    }

    func isItemLimitError(_ error: Error) -> Bool {
        Self.serverMessage(from: error).contains("FREE_TIER_ITEM_LIMIT")
    }

    func isEntitlementRequiredError(_ error: Error) -> Bool {
        Self.serverMessage(from: error).contains("ENTITLEMENT_REQUIRED")
    }

    /// Postgres errors arrive wrapped by postgrest-swift, and which field
    /// carries the raised message varies by error shape. Checking the
    /// description of both the error and any underlying `EntitlementError`
    /// covers the paths this app actually produces without depending on the
    /// SDK's internal error type.
    private static func serverMessage(from error: Error) -> String {
        if let entitlementError = error as? EntitlementError {
            return entitlementError.errorDescription ?? ""
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(describing: error)
    }

    private func currentUserID() async -> UUID? {
        (try? await client.auth.session)?.user.id
    }
}
