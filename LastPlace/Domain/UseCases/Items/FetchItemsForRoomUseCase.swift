//
//  FetchItemsForRoomUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchItemsForRoomUseCase: Sendable {
    func execute(roomID: UUID) async throws -> [StoredItem]
}

struct DefaultFetchItemsForRoomUseCase: FetchItemsForRoomUseCase {
    let itemRepository: ItemRepository

    func execute(roomID: UUID) async throws -> [StoredItem] {
        try await itemRepository.fetchItems(roomID: roomID)
    }
}
