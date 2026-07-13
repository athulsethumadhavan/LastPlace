//
//  ToggleItemImportanceUseCase.swift
//  LastPlace
//

import Foundation

protocol ToggleItemImportanceUseCase: Sendable {
    func execute(itemID: UUID) async throws -> StoredItem
}

struct DefaultToggleItemImportanceUseCase: ToggleItemImportanceUseCase {
    let itemRepository: ItemRepository

    func execute(itemID: UUID) async throws -> StoredItem {
        let current = try await itemRepository.fetchItem(itemID: itemID)
        return try await itemRepository.setImportant(itemID: itemID, isImportant: !current.isImportant)
    }
}
