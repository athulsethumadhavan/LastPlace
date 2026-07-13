//
//  ItemRepository.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol ItemRepository: Sendable {
    func fetchItem(itemID: UUID) async throws -> StoredItem
    func fetchItems(roomID: UUID) async throws -> [StoredItem]
    func fetchRecentItems(limit: Int) async throws -> [StoredItem]
    func fetchImportantItems() async throws -> [StoredItem]

    /// Searches across name, category display name, room name, location description, and notes.
    func search(query: String) async throws -> [StoredItem]

    func create(_ item: StoredItem) async throws -> StoredItem
    func update(_ item: StoredItem) async throws -> StoredItem
    func updateLocation(itemID: UUID, description: String, imagePath: String?, at date: Date) async throws -> StoredItem
    func move(itemID: UUID, toRoomID: UUID) async throws -> StoredItem
    func setImportant(itemID: UUID, isImportant: Bool) async throws -> StoredItem
    func delete(itemID: UUID) async throws
}
