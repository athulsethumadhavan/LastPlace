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
    /// same store.
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
        let storeURL = resolvedStoreURL()
        do {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            let localConfiguration = ModelConfiguration(schema: schema, url: storeURL)
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

    /// Lightweight, repository-only container for the widget extension —
    /// same store, but the widget has no reason to link `AppDependencyContainer`'s
    /// full dependency graph (Vision, AVFoundation, etc.), which would bloat
    /// an extension that has a tight memory budget. CloudKit is left off
    /// here deliberately: a widget's timeline refresh is a poor place to
    /// eat the cost/latency of standing up CloudKit mirroring, and the main
    /// app keeps the store synced regardless of what reads it.
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
}
