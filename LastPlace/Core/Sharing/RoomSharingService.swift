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

enum RoomSharingError: LocalizedError, Sendable {
    case notAuthenticated
    case notOwner
    case noAccountFound
    case inviteFailed(underlying: String)
    case fetchFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to share a room."
        case .notOwner:
            return "Only the room's owner can manage sharing for it."
        case .noAccountFound:
            return "No LastPlace account was found for that email address."
        case .inviteFailed(let underlying), .fetchFailed(let underlying):
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
    func loadSharedImageData(path: String) async throws -> Data

    /// Live updates to the current user's incoming shares (new invites,
    /// revocations) via Supabase Realtime.
    func observeIncomingShares() -> AsyncStream<[RoomShare]>
}
