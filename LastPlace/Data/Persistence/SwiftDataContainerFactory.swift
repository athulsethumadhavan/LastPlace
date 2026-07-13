//
//  SwiftDataContainerFactory.swift
//  LastPlace
//
//  Builds the shared `ModelContainer`. Repositories create their own
//  `@ModelActor`-backed `ModelContext` from this container.
//

import Foundation
import SwiftData

enum SwiftDataContainerFactory {
    /// The full set of `@Model` types the app persists — kept in one place so
    /// migrations and container variants stay in sync.
    static let schemaTypes: [any PersistentModel.Type] = [
        HomeEntity.self,
        RoomEntity.self,
        StoredItemEntity.self,
        ItemSnapshotEntity.self,
        ScanSessionEntity.self,
        ChecklistEntity.self,
        ChecklistEntryEntity.self
    ]

    /// Production container backed by disk in the app's default location.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// In-memory container for previews and integration tests.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
