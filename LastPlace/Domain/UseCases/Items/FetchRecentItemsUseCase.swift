//
//  FetchRecentItemsUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchRecentItemsUseCase: Sendable {
    func execute(limit: Int) async throws -> [StoredItem]
}

struct DefaultFetchRecentItemsUseCase: FetchRecentItemsUseCase {
    let itemRepository: ItemRepository

    func execute(limit: Int = 8) async throws -> [StoredItem] {
        try await itemRepository.fetchRecentItems(limit: limit)
    }
}
