//
//  SwiftDataSnapshotRepository.swift
//  LastPlace
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataSnapshotRepository: SnapshotRepository {
    func fetchSnapshots(itemID: UUID) async throws -> [ItemSnapshot] {
        let target = itemID
        let descriptor = FetchDescriptor<ItemSnapshotEntity>(
            predicate: #Predicate { $0.itemID == target },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor).map(ItemSnapshotMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Without `@Attribute(.unique)` (unsupported by CloudKit-backed
    /// SwiftData) nothing at the persistence layer stops a second insert
    /// with the same `id` from creating a duplicate row, so this checks
    /// first and updates in place if one is already there.
    func create(_ snapshot: ItemSnapshot) async throws -> ItemSnapshot {
        if let existing = try findEntity(id: snapshot.id) {
            ItemSnapshotMapper.apply(snapshot, to: existing)
            existing.syncStatusRaw = SyncStatus.pendingUpsert.rawValue
            try linkItem(for: existing)
            try saveOrThrow()
            return ItemSnapshotMapper.toDomain(existing)
        }
        let entity = ItemSnapshotMapper.toEntity(snapshot)
        modelContext.insert(entity)
        try linkItem(for: entity)
        try saveOrThrow()
        return ItemSnapshotMapper.toDomain(entity)
    }

    /// See the doc comment on `SwiftDataHomeRepository.delete` for the
    /// hard-delete-vs-`.pendingDelete` reasoning.
    func delete(snapshotID: UUID) async throws {
        let target = snapshotID
        let descriptor = FetchDescriptor<ItemSnapshotEntity>(predicate: #Predicate { $0.id == target })
        do {
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound
            }
            markDeleted(entity)
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        try saveOrThrow()
    }

    func deleteSnapshots(forItemID itemID: UUID) async throws {
        let target = itemID
        let descriptor = FetchDescriptor<ItemSnapshotEntity>(predicate: #Predicate { $0.itemID == target })
        do {
            let entities = try modelContext.fetch(descriptor)
            for entity in entities {
                markDeleted(entity)
            }
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        try saveOrThrow()
    }

    /// See the doc comment on `SwiftDataHomeRepository.delete` for the
    /// hard-delete-vs-`.pendingDelete` reasoning.
    private func markDeleted(_ entity: ItemSnapshotEntity) {
        if entity.syncStatusRaw == SyncStatus.pendingUpsert.rawValue {
            modelContext.delete(entity)
        } else {
            entity.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        }
    }

    /// Plain existence check used by `create`'s dedupe guard — `nil` means
    /// not found.
    private func findEntity(id: UUID) throws -> ItemSnapshotEntity? {
        let target = id
        let descriptor = FetchDescriptor<ItemSnapshotEntity>(predicate: #Predicate { $0.id == target })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Keeps the `item` relationship pointer in sync with the flat `itemID`
    /// field — needed for CloudKit sharing's graph traversal (see the doc
    /// comment on `HomeEntity.rooms`). A no-op if it's already correct.
    private func linkItem(for entity: ItemSnapshotEntity) throws {
        guard entity.item?.id != entity.itemID else { return }
        let target = entity.itemID
        let descriptor = FetchDescriptor<StoredItemEntity>(predicate: #Predicate { $0.id == target })
        do {
            entity.item = try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }
}
