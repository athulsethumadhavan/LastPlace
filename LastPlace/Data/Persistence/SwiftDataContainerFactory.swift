//
//  SwiftDataContainerFactory.swift
//  LastPlace
//
//  Builds the shared `ModelContainer`. Repositories create their own
//  `@ModelActor`-backed `ModelContext` from this container.
//
//  CloudKit compatibility: every `@Model` in `schemaTypes` has to skip
//  `@Attribute(.unique)` and give every non-optional property a default
//  value — CloudKit-backed SwiftData rejects unique constraints outright and
//  requires every attribute to be either Optional or defaulted. The
//  uniqueness `.unique` used to buy is now enforced at the repository layer
//  instead (see the `find*Entity`/dedupe-guard helpers in each
//  `SwiftData*Repository.create`).
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
    ///
    /// Tries `cloudKitDatabase: .automatic` first, which syncs through
    /// whatever iCloud container is declared in the app's entitlements.
    /// That requires the iCloud capability (CloudKit service) to be enabled
    /// in Xcode's Signing & Capabilities with a container assigned —
    /// unlike some SwiftData failures, a missing/misconfigured entitlement
    /// here throws at container creation rather than degrading gracefully,
    /// so this falls back to a local-only configuration if that happens.
    /// Both configurations point at the same on-disk store location, so
    /// once the capability is added in Xcode, the fallback branch stops
    /// being hit and existing local data starts syncing — nothing is lost
    /// in the meantime.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        do {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        }
    }

    /// In-memory container for previews and integration tests. CloudKit
    /// sync requires a persistent store, so this stays local-only
    /// (`cloudKitDatabase` defaults to `.none`) regardless of the production
    /// container's setting.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
