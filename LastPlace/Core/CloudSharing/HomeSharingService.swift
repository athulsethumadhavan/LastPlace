//
//  HomeSharingService.swift
//  LastPlace
//
//  "Family Find" is deliberately a READ-ONLY shared snapshot, not
//  bidirectional shared editing. SwiftData has no supported path to
//  CloudKit's shared database (no `ModelContext.share(...)` API, no way to
//  point its sync at a custom `CKRecordZone`), so real multi-user editing
//  would require a second, hand-rolled CloudKit repository stack running
//  alongside SwiftData. That's out of scope here.
//
//  Instead, this publishes one denormalized JSON snapshot per home (rooms +
//  items, text only — no photos, see `HomeSharePayload`) to a single custom
//  `CKRecordZone` per home, shares that zone's root record via `CKShare`,
//  and lets participants fetch a read-only copy on demand. One record, one
//  zone, one share per home keeps the whole thing small enough to reason
//  about without a compiler to check it.
//
//  Protocol-wrapped CloudKit, mirroring `BiometricAuthenticator` /
//  `CameraCaptureService` — so view models and previews never import
//  CloudKit directly and can inject `MockHomeSharingService` instead.
//

import Foundation
import CloudKit

/// A read-only copy of another household's shared home, as seen from the
/// participant side. Plain value type — no CloudKit types leak past this.
struct SharedHomeSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID { homeID }
    let homeID: UUID
    let homeName: String
    let ownerDisplayName: String
    let updatedAt: Date
    let rooms: [SharedRoomSnapshot]

    var itemCount: Int { rooms.reduce(0) { $0 + $1.items.count } }
}

struct SharedRoomSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let items: [SharedItemSnapshot]
}

struct SharedItemSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let locationDescription: String
    let isImportant: Bool
    let lastSeenAt: Date
}

enum HomeSharingError: LocalizedError, Sendable {
    case containerUnavailable
    case shareCreationFailed(underlying: String)
    case fetchFailed(underlying: String)
    case acceptFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "iCloud isn't available. Make sure you're signed in under Settings and try again."
        case .shareCreationFailed(let underlying):
            return "Couldn't set up sharing: \(underlying)"
        case .fetchFailed(let underlying):
            return "Couldn't load shared homes: \(underlying)"
        case .acceptFailed(let underlying):
            return "Couldn't accept that invitation: \(underlying)"
        }
    }
}

protocol HomeSharingService: Sendable {
    /// The container sharing operates against — `CloudSharingViewRepresentable`
    /// needs it to construct `UICloudSharingController`.
    var container: CKContainer { get }

    /// Publishes (or re-publishes) the given home's current rooms/items as
    /// a read-only snapshot, creating the share on first call and just
    /// updating the record's contents on subsequent calls. Returns the
    /// `CKShare` to present in `UICloudSharingController`.
    func shareOrRefresh(home: Home, rooms: [Room], items: [StoredItem]) async throws -> CKShare

    /// `true` if this home already has an active share — lets the UI show
    /// "Manage Sharing" instead of "Share Home".
    func isShared(homeID: UUID) async throws -> Bool

    /// Deletes the home's sharing zone entirely, which revokes every
    /// participant's access in one step.
    func stopSharing(homeID: UUID) async throws

    /// Accepts an incoming share invitation. Safe to call for a share
    /// that's already been accepted (CloudKit treats it as a no-op).
    func acceptShare(metadata: CKShare.Metadata) async throws

    /// Every home shared with the current user, freshly fetched from the
    /// shared database. No caching — "read-only, refreshed on demand" per
    /// the scope decision, so this is meant to be called each time the
    /// Shared Homes screen appears or the user pulls to refresh.
    func fetchSharedSnapshots() async throws -> [SharedHomeSnapshot]
}
