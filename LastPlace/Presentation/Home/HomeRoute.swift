//
//  HomeRoute.swift
//  LastPlace
//

import Foundation

enum HomeRoute: Hashable {
    case roomDetail(roomID: UUID)
    case createRoom
    case editRoom(roomID: UUID)
    case itemDetail(itemID: UUID)
    case updateItemLocation(itemID: UUID)
    case scanRoom(roomID: UUID)
    case shareRoom(roomID: UUID)
    case giftItem(itemID: UUID)
    /// A room someone else owns and has shared with this user, opened from
    /// Home's "Shared with you" section. Distinct from `roomDetail`, which
    /// reads local SwiftData and offers owner-only actions (scan, edit,
    /// delete, share) that make no sense on a room you can only read.
    /// `ownerID` is required to resolve images out of the owner's Storage
    /// folder.
    case sharedRoomDetail(roomID: UUID, ownerID: UUID)
    /// An item inside a shared room. Separate from `itemDetail`, which reads
    /// local SwiftData and offers owner-only actions.
    case sharedItemDetail(itemID: UUID, roomID: UUID, ownerID: UUID)
}
