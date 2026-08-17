//
//  HomeDashboardContent.swift
//  LastPlace
//

import Foundation

/// One room another account has shared with this user, flattened for Home.
///
/// Deliberately its own type rather than reusing Settings'
/// `IncomingShareSummary`: Home only ever renders *accepted* shares, so it
/// has no use for the pending-invite machinery (accept/decline, the share
/// id, `invitedAt`), and a `Room` that's always present reads better here
/// than one that's optional because a fetch might have failed.
struct HomeSharedRoom: Identifiable, Sendable {
    let room: Room
    /// Needed to load the room's images out of the *owner's* Storage
    /// folder -- see `RoomSharingService.loadSharedImageData(path:ownerID:)`.
    let ownerID: UUID
    /// Nil when the owner's profile couldn't be fetched; the card falls
    /// back to a generic label rather than hiding the room.
    let ownerLabel: String?

    var id: UUID { room.id }
}

struct HomeDashboardContent: Sendable {
    let home: Home
    let rooms: [Room]
    let recentItems: [StoredItem]
    let importantItems: [StoredItem]
    /// Rooms shared *with* this user. Never mirrored into local SwiftData
    /// (see the note atop `RoomSharingService`), so unlike every other
    /// field here this one is fetched live and comes back empty when
    /// offline.
    let sharedRooms: [HomeSharedRoom]

    /// Drives the "No rooms yet" empty state. Shared rooms count: someone
    /// whose only room was shared with them has something to look at, and
    /// showing them a create-your-first-room screen with a populated
    /// section scrolled underneath it would be plainly wrong.
    var isFullyEmpty: Bool {
        rooms.isEmpty && recentItems.isEmpty && importantItems.isEmpty && sharedRooms.isEmpty
    }
}
