//
//  SettingsRoute.swift
//  LastPlace
//

import Foundation

// `appearance` and `account` were removed rather than left unused:
// appearance is now a `Menu` in `SettingsView` and account is an inline
// header plus two action rows there. Keeping dead routes around invites
// someone to push one later and land on a screen nothing else maintains.
enum SettingsRoute: Hashable {
    case privacy
    case permissions
    case security
    case dataManagement
    case sharedRooms
    case sharedRoomDetail(roomID: UUID, ownerID: UUID)
    case gifts
}
