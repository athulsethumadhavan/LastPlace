//
//  MoveItemToRoomUseCase.swift
//  LastPlace
//

import Foundation

protocol MoveItemToRoomUseCase: Sendable {
    func execute(itemID: UUID, toRoomID: UUID) async throws -> StoredItem
}

struct DefaultMoveItemToRoomUseCase: MoveItemToRoomUseCase {
    let itemRepository: ItemRepository
    let roomRepository: RoomRepository

    func execute(itemID: UUID, toRoomID: UUID) async throws -> StoredItem {
        _ = try await roomRepository.fetchRoom(roomID: toRoomID)
        return try await itemRepository.move(itemID: itemID, toRoomID: toRoomID)
    }
}
