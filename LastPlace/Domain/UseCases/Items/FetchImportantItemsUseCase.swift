//
//  FetchImportantItemsUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchImportantItemsUseCase: Sendable {
    func execute() async throws -> [StoredItem]
}

struct DefaultFetchImportantItemsUseCase: FetchImportantItemsUseCase {
    let itemRepository: ItemRepository

    func execute() async throws -> [StoredItem] {
        try await itemRepository.fetchImportantItems()
    }
}
