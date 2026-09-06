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

    /// Total live items across every room, for the free-tier cap.
    ///
    /// Counts the *local* store rather than asking Supabase, because item
    /// creation here is local-first: `SaveItemUseCase` writes SwiftData and
    /// `SyncEngine` pushes later. The server's `items` insert trigger is
    /// still the real enforcement, but it only fires at sync time — so a
    /// check against a remote count would happily let someone create ten
    /// more items offline that then fail to push.
    ///
    /// Excludes tombstones, matching every other read here: an item the
    /// person deleted has freed its slot even before the delete syncs.
    func countItems() async throws -> Int

    func create(_ item: StoredItem) async throws -> StoredItem
    func update(_ item: StoredItem) async throws -> StoredItem
    func updateLocation(itemID: UUID, description: String, imagePath: String?, at date: Date) async throws -> StoredItem
    func move(itemID: UUID, toRoomID: UUID) async throws -> StoredItem
    func setImportant(itemID: UUID, isImportant: Bool) async throws -> StoredItem
    func delete(itemID: UUID) async throws
}
