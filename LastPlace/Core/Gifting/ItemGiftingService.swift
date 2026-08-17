//
//  ItemGiftingService.swift
//  LastPlace
//
//  Phase 5 — Item Gifting. A one-time ownership transfer between two
//  registered LastPlace accounts, distinct from Phase 4's room sharing
//  (which only grants view access, never ownership). The owner gifts a
//  snapshot of one item by the recipient's email; the recipient accepts it
//  into a room of their own choosing (which creates a fully independent
//  item + photo copy) or declines. `origin_shared_by` on the resulting
//  item is a soft breadcrumb for Phase 6's push notifications.
//

import Foundation

enum ItemGiftStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}

/// Domain-facing shape of an `item_gifts` row. Deliberately snapshot-only
/// (name/category/notes/location/photo path as they were at gift time) —
/// it doesn't reference the original `StoredItem` live, since edits or
/// deletion of the original after gifting shouldn't affect what the
/// recipient sees before they accept.
struct ItemGift: Identifiable, Hashable, Sendable {
    let id: UUID
    var fromUserID: UUID
    var toUserID: UUID
    var status: ItemGiftStatus
    var itemName: String
    var itemCategory: ItemCategory
    var itemNotes: String?
    var itemLocationDescription: String
    var sourceImagePath: String?
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedItemID: UUID?
}

enum ItemGiftingError: LocalizedError, Sendable {
    case notAuthenticated
    case notOwner
    case noAccountFound
    case alreadyResolved
    case roomNotOwned
    /// The item already has another gift out that's still `pending` --
    /// `gift_item` enforces this with an explicit check plus a partial
    /// unique index (`item_gifts_one_pending_per_item`) as the race-proof
    /// backstop, so this can surface either as the friendly raised
    /// exception or, rarely, as the underlying constraint violation.
    case alreadyPendingGift
    case sendFailed(underlying: String)
    case fetchFailed(underlying: String)
    case acceptFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to gift an item."
        case .notOwner:
            return "Only the item's owner can gift it."
        case .noAccountFound:
            return "No LastPlace account was found for that email address."
        case .alreadyResolved:
            return "This gift has already been accepted or declined."
        case .roomNotOwned:
            // Reached when the `accept_gift` RPC can't find the chosen room
            // under the caller's user id. In practice the likeliest cause
            // isn't picking someone else's room -- the picker only ever
            // lists your own -- but a room that hasn't finished syncing to
            // the server yet, so the message leads with that.
            return "That room hasn't finished syncing yet. Check your connection and try again in a moment."
        case .alreadyPendingGift:
            return "This item already has a pending gift. Cancel it before sending another."
        case .sendFailed(let underlying), .fetchFailed(let underlying), .acceptFailed(let underlying):
            return underlying
        }
    }
}

/// Owner-side and recipient-side operations for Phase 5 gifting. Like
/// `RoomSharingService`, this reads/writes Supabase directly — a gift, and
/// the items it produces, aren't candidates for the local-cache-plus-sync
/// model until the resulting item is pulled down by the recipient's own
/// `SyncEngine` on their next sync.
protocol ItemGiftingService: Sendable {
    /// Owner-only. Snapshots the item's current fields and looks the
    /// recipient up by email via the `gift_item` Postgres function.
    func giftItem(itemID: UUID, recipientEmail: String) async throws -> ItemGift

    /// Gifts the current user has sent, any status.
    func outgoingGifts() async throws -> [ItemGift]

    /// Gifts sent to the current user, any status.
    func incomingGifts() async throws -> [ItemGift]

    /// Sender-only. Withdraws a gift that hasn't been resolved yet.
    func cancelGift(_ giftID: UUID) async throws

    /// Recipient-only. Marks a pending gift declined.
    func declineGift(_ giftID: UUID) async throws

    /// Recipient-only. Copies the gift's photo (if any) into the caller's
    /// own Storage folder, then creates an independent `StoredItem` in the
    /// given room via the `accept_gift` Postgres function, atomically
    /// resolving the gift in the same call. Also returns the same image
    /// bytes this already downloaded as part of that copy, so the caller
    /// can write them into local storage (`ImageStorageService`) without a
    /// second round trip — the accepted item is the recipient's own now
    /// and belongs in local-cache-plus-sync like anything else they own,
    /// unlike shared-room content which never touches local storage.
    func acceptGift(_ giftID: UUID, intoRoomID roomID: UUID) async throws -> (item: StoredItem, imageData: Data?)

    /// Downloads a gift's snapshot photo straight from the sender's Storage
    /// folder, for display in the Gifts list before the recipient has
    /// accepted anything (at which point they have no local copy of their
    /// own yet).
    ///
    /// `sourcePath` is the bare filename from `item_gifts.source_image_path`
    /// and `senderID` its `from_user_id` -- both needed because Storage keys
    /// are `{owner_id}/{filename}` and the owner here is the *other*
    /// account. Mirrors `RoomSharingService.loadSharedImageData`.
    ///
    /// Expect this to fail for a gift that's already been accepted or
    /// declined: the "Gift recipient can read the source item image" RLS
    /// policy only grants the recipient access while `status = 'pending'`.
    /// Callers should degrade gracefully rather than treat that as an error.
    func loadGiftImageData(sourcePath: String, senderID: UUID) async throws -> Data

    func fetchProfile(userID: UUID) async throws -> SharingProfile?

    /// Live updates to the current user's incoming gifts via Supabase
    /// Realtime.
    func observeIncomingGifts() -> AsyncStream<[ItemGift]>
}
