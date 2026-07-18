//
//  SwiftDataItemRepository.swift
//  LastPlace
//
//  Search implementation filters in memory. For the MVP dataset size (a
//  household's worth of items) this is more predictable than pushing #Predicate
//  string search across multiple optional columns.
//

import Foundation
import SwiftData
import WidgetKit

@ModelActor
actor SwiftDataItemRepository: ItemRepository {
    func fetchItem(itemID: UUID) async throws -> StoredItem {
        let entity = try fetchEntity(id: itemID)
        return StoredItemMapper.toDomain(entity)
    }

    func fetchItems(roomID: UUID) async throws -> [StoredItem] {
        let target = roomID
        let descriptor = FetchDescriptor<StoredItemEntity>(
            predicate: #Predicate { $0.roomID == target },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor).map(StoredItemMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    func fetchRecentItems(limit: Int) async throws -> [StoredItem] {
        var descriptor = FetchDescriptor<StoredItemEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit)
        do {
            return try modelContext.fetch(descriptor).map(StoredItemMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    func fetchImportantItems() async throws -> [StoredItem] {
        let descriptor = FetchDescriptor<StoredItemEntity>(
            predicate: #Predicate { $0.isImportant == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor).map(StoredItemMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    func search(query: String) async throws -> [StoredItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        do {
            let items = try modelContext.fetch(FetchDescriptor<StoredItemEntity>())
            let rooms = try modelContext.fetch(FetchDescriptor<RoomEntity>())
            let roomsByID = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })

            let matches = items.filter { item in
                if item.name.lowercased().contains(trimmed) { return true }
                if item.locationDescription.lowercased().contains(trimmed) { return true }
                if let notes = item.notes, notes.lowercased().contains(trimmed) { return true }
                if let category = ItemCategory(rawValue: item.categoryRaw),
                   category.displayName.lowercased().contains(trimmed) {
                    return true
                }
                if let room = roomsByID[item.roomID], room.name.lowercased().contains(trimmed) {
                    return true
                }
                return false
            }
            return matches
                .sorted { $0.updatedAt > $1.updatedAt }
                .map(StoredItemMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Without `@Attribute(.unique)` (unsupported by CloudKit-backed
    /// SwiftData) nothing at the persistence layer stops a second insert
    /// with the same `id` from creating a duplicate row, so this checks
    /// first and updates in place if one is already there.
    func create(_ item: StoredItem) async throws -> StoredItem {
        let validated = try item.validated()
        if let existing = try findEntity(id: validated.id) {
            StoredItemMapper.apply(validated, to: existing)
            try linkRoom(for: existing)
            try saveOrThrow()
            return StoredItemMapper.toDomain(existing)
        }
        let entity = StoredItemMapper.toEntity(validated)
        modelContext.insert(entity)
        try linkRoom(for: entity)
        try saveOrThrow()
        return StoredItemMapper.toDomain(entity)
    }

    func update(_ item: StoredItem) async throws -> StoredItem {
        let validated = try item.validated()
        let entity = try fetchEntity(id: validated.id)
        StoredItemMapper.apply(validated, to: entity)
        try linkRoom(for: entity)
        try saveOrThrow()
        return StoredItemMapper.toDomain(entity)
    }

    func updateLocation(itemID: UUID, description: String, imagePath: String?, at date: Date) async throws -> StoredItem {
        let entity = try fetchEntity(id: itemID)
        entity.locationDescription = description
        if let imagePath {
            entity.imagePath = imagePath
        }
        entity.lastSeenAt = date
        entity.updatedAt = date
        try saveOrThrow()
        return StoredItemMapper.toDomain(entity)
    }

    func move(itemID: UUID, toRoomID: UUID) async throws -> StoredItem {
        let entity = try fetchEntity(id: itemID)
        entity.roomID = toRoomID
        entity.updatedAt = Date()
        try linkRoom(for: entity)
        try saveOrThrow()
        return StoredItemMapper.toDomain(entity)
    }

    func setImportant(itemID: UUID, isImportant: Bool) async throws -> StoredItem {
        let entity = try fetchEntity(id: itemID)
        entity.isImportant = isImportant
        entity.updatedAt = Date()
        try saveOrThrow()
        return StoredItemMapper.toDomain(entity)
    }

    func delete(itemID: UUID) async throws {
        let entity = try fetchEntity(id: itemID)
        modelContext.delete(entity)
        try saveOrThrow()
    }

    private func fetchEntity(id: UUID) throws -> StoredItemEntity {
        let target = id
        let descriptor = FetchDescriptor<StoredItemEntity>(predicate: #Predicate { $0.id == target })
        do {
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound
            }
            return entity
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Plain existence check used by `create`'s dedupe guard — `nil` means
    /// not found, unlike `fetchEntity` which throws `.notFound`.
    private func findEntity(id: UUID) throws -> StoredItemEntity? {
        let target = id
        let descriptor = FetchDescriptor<StoredItemEntity>(predicate: #Predicate { $0.id == target })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Keeps the `room` relationship pointer in sync with the flat `roomID`
    /// field — needed for CloudKit sharing's graph traversal (see the doc
    /// comment on `HomeEntity.rooms`). A no-op if it's already correct, so
    /// this is cheap to call unconditionally on every write.
    private func linkRoom(for entity: StoredItemEntity) throws {
        guard entity.room?.id != entity.roomID else { return }
        let target = entity.roomID
        let descriptor = FetchDescriptor<RoomEntity>(predicate: #Predicate { $0.id == target })
        do {
            entity.room = try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Reloading widget timelines on every save is a bit coarse, but
    /// `WidgetCenter` calls are cheap and system-throttled, so precision
    /// isn't worth chasing here — the Recent Items widget wants to catch
    /// every one of these anyway.
    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
