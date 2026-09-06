//
//  EntitlementService.swift
//  LastPlace
//
//  Phase 7 — Monetization, free tier first.
//
//  Reads subscription state; never writes it. The `entitlements` table has
//  RLS granting SELECT to the row's owner and **no write policy for any
//  role** — the RevenueCat webhook writes it with the service key. A client
//  that can grant itself an entitlement isn't a paywall, so there is
//  deliberately no `grant`-shaped method anywhere in this protocol.
//
//  Every check here is a courtesy to the person using the app, not a
//  security boundary. The real enforcement lives in Postgres:
//
//    * the item cap is a BEFORE INSERT trigger on `items`
//    * `accept_gift` re-checks the cap before touching anything
//    * `identify-item` refuses with 402 unless the caller is entitled
//
//  This exists so someone hits a clear explanation instead of a failed
//  write, and so a free user falls back to on-device Vision instantly
//  rather than waiting on a network round-trip that was always going to
//  refuse.
//

import Foundation

/// What the current account may do, as of the last check.
struct EntitlementStatus: Equatable, Sendable {
    var isPremium: Bool
    /// Item slots left on the free tier. Nil means unlimited, which is what
    /// premium reports — deliberately not `Int.max`, so "unlimited" can't be
    /// accidentally rendered as a number or compared against.
    var remainingItemSlots: Int?

    /// The free-tier cap. Mirrored from `free_tier_item_limit()` in
    /// Postgres. Duplicated rather than fetched because it's needed to
    /// render "3 of 10 used" before any network call completes; the server
    /// is the authority if they ever disagree.
    static let freeItemLimit = 10

    /// Conservative default used before the first successful read, and
    /// whenever a check fails. Free rather than premium on purpose: guessing
    /// "premium" would show someone features that then fail against the
    /// database, which is worse than briefly under-offering.
    static let free = EntitlementStatus(isPremium: false, remainingItemSlots: freeItemLimit)

    var canAddItem: Bool {
        guard let remainingItemSlots else { return true }
        return remainingItemSlots > 0
    }

    /// How many of the free allowance are in use, for display. Nil for
    /// premium, where there's nothing meaningful to show.
    var itemsUsed: Int? {
        guard let remainingItemSlots else { return nil }
        return max(0, Self.freeItemLimit - remainingItemSlots)
    }
}

/// Which gate someone ran into. Drives what the paywall says — arriving via
/// a full inventory and arriving via a gift are different situations and
/// shouldn't produce the same screen.
/// `Identifiable` so it can drive `.sheet(item:)` directly — presenting the
/// paywall and saying why are the same decision, and splitting them into a
/// separate `isPresented` bool invites the two drifting apart.
enum PaywallReason: String, Identifiable, Equatable, Sendable {
    var id: String { rawValue }

    case itemLimitReached
    case aiIdentification
    case sendGift
    /// A gift they can't accept because their inventory is full.
    case acceptGiftAtLimit

    var title: String {
        switch self {
        case .itemLimitReached:  return "You've used all \(EntitlementStatus.freeItemLimit) free items"
        case .aiIdentification:  return "Smart naming is a premium feature"
        case .sendGift:          return "Sending items is a premium feature"
        case .acceptGiftAtLimit: return "No room for this gift yet"
        }
    }

    var message: String {
        switch self {
        case .itemLimitReached:
            return "Upgrade to add more items. Everything you've already saved stays exactly where it is."
        case .aiIdentification:
            return "Premium names items for you from the photo. Without it, scanning still works using on-device recognition."
        case .sendGift:
            return "Upgrade to send an item to someone else. Receiving items is always free."
        case .acceptGiftAtLimit:
            return "Your \(EntitlementStatus.freeItemLimit) free items are all in use. Upgrade to accept this, or remove an item to make space."
        }
    }
}

enum EntitlementError: LocalizedError, Sendable {
    case notAuthenticated
    case lookupFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to check your subscription."
        case .lookupFailed(let underlying):
            return underlying
        }
    }
}

protocol EntitlementService: Sendable {
    /// Current status, read fresh. Callers that need it repeatedly should
    /// hold the result rather than calling in a loop — this is a network
    /// round-trip.
    func status() async throws -> EntitlementStatus

    /// Whether the server refused because of the free-tier item cap.
    ///
    /// Matches the `FREE_TIER_ITEM_LIMIT:` token that both the `items`
    /// trigger and `accept_gift` put in their error messages, rather than
    /// matching on the human-readable prose around it — so rewording the
    /// message later can't silently stop the paywall appearing.
    func isItemLimitError(_ error: Error) -> Bool

    /// Whether the server refused because the feature needs a subscription.
    /// Matches the `ENTITLEMENT_REQUIRED` code `identify-item` returns
    /// alongside its 402.
    func isEntitlementRequiredError(_ error: Error) -> Bool
}

extension EntitlementService {
    /// Non-throwing convenience for call sites where a failed lookup should
    /// degrade rather than surface an error — showing the free tier is a
    /// reasonable thing to do when the network is down, whereas an alert
    /// about subscription lookup is not.
    func statusOrFree() async -> EntitlementStatus {
        (try? await status()) ?? .free
    }
}
