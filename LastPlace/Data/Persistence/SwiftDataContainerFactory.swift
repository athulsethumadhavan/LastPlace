//
//  SwiftDataContainerFactory.swift
//  LastPlace
//
//  Builds the shared `ModelContainer`. Repositories create their own
//  `@ModelActor`-backed `ModelContext` from this container.
//
//  Local-only store: this app no longer syncs through CloudKit (removed in
//  favor of the Supabase-backed data layer landing in Phase 2 of the
//  cross-platform roadmap). `schemaTypes` still avoids `@Attribute(.unique)`
//  and gives every non-optional property a default value, since that's a
//  reasonable SwiftData habit independent of CloudKit and changing it isn't
//  worth the migration risk right now; uniqueness is enforced at the
//  repository layer instead (see the `find*Entity`/dedupe-guard helpers in
//  each `SwiftData*Repository.create`).
//
//  Store location: the widget extension needs to read the same data, which
//  means the store has to live in the shared App Group container rather
//  than the app's own private sandbox — a widget extension is a separate
//  process with its own sandbox and can't see the main app's Application
//  Support directory at all.
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

    /// Must match the App Group entitlement on both the main app target and
    /// the widget extension target — Xcode registers this string when the
    /// "App Groups" capability is added in Signing & Capabilities.
    private static let appGroupIdentifier = "group.com.atsIOSDev.LastPlace"
    private static let storeFileName = "default.store"

    /// Production container backed by disk, in the App Group's shared
    /// container when that's available so the widget extension can read the
    /// same store. Local-only for now — no CloudKit, no other sync. Until
    /// the Supabase data layer (roadmap Phase 2) ships, this is the only
    /// copy of a user's data: nothing backs it up off-device.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        let configuration = ModelConfiguration(schema: schema, url: resolvedStoreURL())
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// In-memory container for previews and integration tests.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Lightweight, repository-only container for the widget extension —
    /// same store, but the widget has no reason to link `AppDependencyContainer`'s
    /// full dependency graph (Vision, AVFoundation, etc.), which would bloat
    /// an extension that has a tight memory budget.
    static func makeWidgetContainer() throws -> ModelContainer {
        let schema = Schema(schemaTypes)
        let configuration = ModelConfiguration(schema: schema, url: resolvedStoreURL())
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Picks the store location the widget extension can also read: the App
    /// Group's shared container if it's available, falling back to the
    /// app's own sandbox otherwise (e.g. running before the widget target
    /// and matching entitlement exist yet, or in a context without the App
    /// Group configured). The first time the shared location is used, this
    /// copies over any store already sitting in the old app-only location
    /// so existing data isn't orphaned by the move.
    private static func resolvedStoreURL() -> URL {
        guard let sharedDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return legacyStoreURL
        }
        let sharedStoreURL = sharedDirectory.appendingPathComponent(storeFileName)
        migrateLegacyStoreIfNeeded(to: sharedStoreURL)
        return sharedStoreURL
    }

    private static var legacyStoreURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(storeFileName)
    }

    /// One-time, best-effort copy from the pre-App-Group store location to
    /// the shared one. SwiftData's SQLite store is three files (the store
    /// itself plus `-shm`/`-wal` journal sidecars); only files that exist
    /// get copied. Failures are swallowed deliberately — if a device
    /// somehow can't migrate, the app just starts fresh at the new
    /// location rather than failing to launch, and CloudKit repopulates
    /// from other devices once sync catches up.
    private static func migrateLegacyStoreIfNeeded(to sharedStoreURL: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: sharedStoreURL.path) else { return }
        guard fileManager.fileExists(atPath: legacyStoreURL.path) else { return }

        for (source, destination) in zip(storeFileVariants(for: legacyStoreURL), storeFileVariants(for: sharedStoreURL))
        where fileManager.fileExists(atPath: source.path) {
            try? fileManager.copyItem(at: source, to: destination)
        }
    }

    private static func storeFileVariants(for storeURL: URL) -> [URL] {
        let base = storeURL.deletingPathExtension()
        let ext = storeURL.pathExtension
        return [
            storeURL,
            base.appendingPathExtension("\(ext)-shm"),
            base.appendingPathExtension("\(ext)-wal")
        ]
    }

    /// One-time backfill for data created before the `@Relationship`
    /// properties existed (`HomeEntity.rooms`, `RoomEntity.items`,
    /// `ItemSnapshotEntity.item`, `ChecklistEntryEntity.checklist`/
    /// `linkedItem`, etc.) — walks every entity whose relationship pointer
    /// is still `nil` and resolves it from the existing flat UUID field.
    ///
    /// Safe to call on every launch: entities that already have their
    /// relationship set are skipped (`where` clauses below), so after the
    /// first run this is just a handful of cheap fetches with nothing to
    /// change. Call once, right after `makeContainer()` succeeds, before
    /// any repository reads/writes.
    @MainActor
    static func backfillRelationships(in container: ModelContainer) {
        let context = container.mainContext

        do {
            let homes = try context.fetch(FetchDescriptor<HomeEntity>())
            let homesByID = Dictionary(uniqueKeysWithValues: homes.map { ($0.id, $0) })

            let rooms = try context.fetch(FetchDescriptor<RoomEntity>())
            for room in rooms where room.home == nil {
                room.home = homesByID[room.homeID]
            }
            let roomsByID = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })

            let items = try context.fetch(FetchDescriptor<StoredItemEntity>())
            for item in items where item.room == nil {
                item.room = roomsByID[item.roomID]
            }
            let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

            let snapshots = try context.fetch(FetchDescriptor<ItemSnapshotEntity>())
            for snapshot in snapshots where snapshot.item == nil {
                snapshot.item = itemsByID[snapshot.itemID]
            }

            let checklists = try context.fetch(FetchDescriptor<ChecklistEntity>())
            let checklistsByID = Dictionary(uniqueKeysWithValues: checklists.map { ($0.id, $0) })

            let entries = try context.fetch(FetchDescriptor<ChecklistEntryEntity>())
            for entry in entries {
                if entry.checklist == nil {
                    entry.checklist = checklistsByID[entry.checklistID]
                }
                if entry.linkedItem == nil, let linkedItemID = entry.linkedItemID {
                    entry.linkedItem = itemsByID[linkedItemID]
                }
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            // Best-effort. If this fails, existing rows simply stay
            // unlinked until the next time they're written through a
            // repository (which sets the relationship itself) — not worth
            // failing app launch over a backfill.
        }
    }
}
