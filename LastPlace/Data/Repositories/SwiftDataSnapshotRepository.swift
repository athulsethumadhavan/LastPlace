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

    func create(_ snapshot: ItemSnapshot) async throws -> ItemSnapshot {
        let entity = ItemSnapshotMapper.toEntity(snapshot)
        modelContext.insert(entity)
        try saveOrThrow()
        return ItemSnapshotMapper.toDomain(entity)
    }

    func delete(snapshotID: UUID) async throws {
        let target = snapshotID
        let descriptor = FetchDescriptor<ItemSnapshotEntity>(predicate: #Predicate { $0.id == target })
        do {
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound
            }
            modelContext.delete(entity)
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
                modelContext.delete(entity)
            }
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        try saveOrThrow()
    }

    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }
}
