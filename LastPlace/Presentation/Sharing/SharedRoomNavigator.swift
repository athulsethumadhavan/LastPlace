//
//  SharedRoomNavigator.swift
//  LastPlace
//
//  Shared rooms are reachable from two tabs -- Home's "Shared with you"
//  section and Settings → Shared Rooms -- and each tab owns its own
//  `NavigationPath` with its own route enum. Rather than teach
//  `SharedRoomDetailView` about both, it takes this: the one navigation
//  capability it actually needs.
//
//  Same pattern as `ItemDetailNavigator`, for the same reason.
//

import Foundation

@MainActor
protocol SharedRoomNavigator: AnyObject {
    /// `roomID` and `ownerID` travel with the item because a shared item is
    /// always read through its room (that's the only query RLS permits) and
    /// its images live in the owner's Storage folder.
    func pushSharedItemDetail(itemID: UUID, roomID: UUID, ownerID: UUID)
}
