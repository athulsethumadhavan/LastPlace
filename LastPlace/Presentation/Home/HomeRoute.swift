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
}
