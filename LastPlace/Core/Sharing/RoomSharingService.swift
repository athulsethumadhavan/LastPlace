//
//  RoomSharingService.swift
//  LastPlace
//
//  Phase 4 — Room Sharing. Registered-users-only for this pass: an owner
//  invites another LastPlace account by email, and once accepted that
//  account can see the shared room and its items (read-only; checklists and
//  checklist entries are never shared). Deliberately NOT folded into
//  `SyncEngine`/local SwiftData: shared data belongs to another account and
//  must be read live from Supabase, never mirrored into the viewer's own
//  local store (which is strictly scoped to rows the viewer owns). This
//  mirrors how `AuthService` already sits outside the sync system.
//

import Foundation

/// A single owner → recipient share on one room. Mirrors a row in the
/// `room_shares` table, but this is the Domain-facing shape used by
/// Presentation — the Supabase wire format is kept private inside
/// `SupabaseRoomSharingService`.
struct RoomShare: Identifiable, Hashable, Sendable {
    let id: UUID
    var roomID: UUID
    var ownerID: UUID
    var sharedWithUserID: UUID
    var invitedAt: Date
    var acceptedAt: Date?

    var isAccepted: Bool { acceptedAt != nil }
}

/// Just enough of the other party's `profiles` row to show a name/email in
/// the sharing UI — not a general-purpose user profile type.
struct SharingProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    var email: String?
    var displayName: String?

    var displayLabel: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return email ?? "LastPlace user"
    }
}

/// One entry in a shared item's location history.
///
/// `setBy` is who actually recorded it, which in a shared room is often not
/// the item's owner — that distinction is the whole reason this type carries
/// a profile rather than just a timestamp.
struct SharedItemHistoryEntry: Identifiable, Sendable {
    let id: UUID
    var locationDescription: String
    var capturedAt: Date
    /// Nil for entries recorded before attribution existed, or when the
    /// person's profile isn't readable.
    var setBy: SharingProfile?

    /// Whether this entry was recorded by the person currently signed in.
    /// Drives "you" vs. a name in the UI.
    func wasSetBy(_ userID: UUID?) -> Bool {
        guard let userID, let setBy else { return false }
        return setBy.id == userID
    }
}

enum RoomSharingError: LocalizedError, Sendable {
    case notAuthenticated
    case notOwner
    case noAccountFound
    case notShared
    case inviteFailed(underlying: String)
    case fetchFailed(underlying: String)
    case updateFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to share a room."
        case .notOwner:
            return "Only the room's owner can manage sharing for it."
        case .noAccountFound:
            return "No LastPlace account was found for that email address."
        case .notShared:
            return "You no longer have access to this room."
        case .inviteFailed(let underlying),
             .fetchFailed(let underlying),
             .updateFailed(let underlying):
            return underlying
        }
    }
}

/// Owner-side and recipient-side operations for Phase 4 sharing. All calls
/// go straight to Supabase — there is no offline/local-cache story for
/// shared content, unlike every other repository in this app.
protocol RoomSharingService: Sendable {
    /// Owner-only. Looks the invitee up by email via the `invite_to_room`
    /// Postgres function (which also re-invites if a prior share exists).
    func inviteToRoom(roomID: UUID, inviteeEmail: String) async throws -> RoomShare

    /// Owner-side: everyone currently invited/sharing on one of the owner's
    /// own rooms.
    func outgoingShares(roomID: UUID) async throws -> [RoomShare]

    /// Recipient-side: every share, pending or accepted, sent to the
    /// current user.
    func incomingShares() async throws -> [RoomShare]

    /// Recipient-only. Sets `accepted_at` on their own share row.
    func acceptShare(_ shareID: UUID) async throws

    /// Either side: recipient declining/leaving, or owner revoking access.
    func removeShare(_ shareID: UUID) async throws

    func fetchProfile(userID: UUID) async throws -> SharingProfile?

    /// Recipient-side read of a room they've accepted a share for, plus its
    /// items — pulled live, never cached locally.
    func fetchSharedRoomDetail(roomID: UUID) async throws -> (room: Room, items: [StoredItem])

    /// On-demand download of an item/room image from Storage for shared
    /// content. Bypasses `ImageStorageService`/`AsyncStoredImage` entirely,
    /// since those are local-file-cache-only and can never hold another
    /// account's images.
    ///
    /// `path` is the bare filename stored in `imagePath`/`coverImagePath`
    /// columns (never a full Storage key) — `SyncEngine` only prepends the
    /// owning user's id when it actually talks to Storage, so callers here
    /// must pass that owner's id too, or the download 404s.
    func loadSharedImageData(path: String, ownerID: UUID) async throws -> Data

    /// Recipient-side location history for a single shared item, newest
    /// first, with each entry attributed to whoever recorded it.
    func sharedItemHistory(itemID: UUID) async throws -> [SharedItemHistoryEntry]

    /// Recipient-side write. The one mutation a viewer is allowed on someone
    /// else's item: where it is.
    ///
    /// Goes through the `update_shared_item_location` Postgres function
    /// rather than a table update, because RLS can restrict which *rows* you
    /// may write but not which *columns*. Granting viewers UPDATE on `items`
    /// would let them rewrite the name, notes, category and importance flag
    /// of another person's inventory, with nothing but client code stopping
    /// them. The function touches exactly `location_description`,
    /// `last_seen_at` and `updated_at`, so the rule is enforced by the
    /// database instead of by good behaviour.
    ///
    /// No photo parameter: a viewer's upload would land in their own Storage
    /// folder while every reader resolves image paths against the item
    /// owner's, so it would be written somewhere nobody looks for it.
    func updateSharedItemLocation(itemID: UUID, description: String) async throws

    /// Live updates to the current user's incoming shares (new invites,
    /// revocations) via Supabase Realtime.
    func observeIncomingShares() -> AsyncStream<[RoomShare]>
}
