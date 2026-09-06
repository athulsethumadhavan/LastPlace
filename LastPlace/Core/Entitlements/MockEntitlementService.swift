//
//  MockEntitlementService.swift
//  LastPlace
//
//  In-memory EntitlementService for previews and `makePreview()`.
//
//  Defaults to the free tier with a full allowance, matching production
//  behaviour for a new account. Previews that want to see a gated screen
//  should set `remainingItemSlots = 0`; previews that want the premium
//  experience should set `isPremium = true`.
//

import Foundation

final class MockEntitlementService: EntitlementService, @unchecked Sendable {
    /// Not named `status` — a stored property and a `status()` method can't
    /// share a name in Swift.
    var currentStatus: EntitlementStatus
    /// Set to have `status()` throw, for exercising the degraded path where
    /// a lookup fails and the app falls back to assuming free.
    var lookupError: Error?

    init(status: EntitlementStatus = .free) {
        self.currentStatus = status
    }

    func status() async throws -> EntitlementStatus {
        if let lookupError { throw lookupError }
        return currentStatus
    }

    func isItemLimitError(_ error: Error) -> Bool {
        String(describing: error).contains("FREE_TIER_ITEM_LIMIT")
    }

    func isEntitlementRequiredError(_ error: Error) -> Bool {
        String(describing: error).contains("ENTITLEMENT_REQUIRED")
    }
}

extension EntitlementStatus {
    /// Convenience for previews of premium-state screens.
    static let premium = EntitlementStatus(isPremium: true, remainingItemSlots: nil)
    /// Convenience for previews of the moment someone hits the cap.
    static let freeExhausted = EntitlementStatus(isPremium: false, remainingItemSlots: 0)
}
