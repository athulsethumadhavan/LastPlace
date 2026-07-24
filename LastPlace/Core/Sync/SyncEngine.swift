//
//  SyncEngine.swift
//  LastPlace
//
//  Two-phase sync against the Supabase tables from `create_inventory_tables`:
//  push local `.pendingUpsert`/`.pendingDelete` rows up, then pull remote
//  rows down into SwiftData. Tables are processed parent-before-child in
//  both directions (homes -> rooms -> items -> item_snapshots, checklists ->
//  checklist_entries) since the Postgres foreign keys are real constraints
//  (a room row references a home row that must already exist server-side)
//  and, on the pull side, inserting a new local entity needs its parent
//  entity to already be resolvable for the `@Relationship` wiring.
//
//  Conflict handling is intentionally simple for this first pass:
//  - Push always wins for a row this device has pending changes for --
//    pull only ever touches rows whose local status is already `.synced`.
//  - For the four tables with `updatedAt`, a pulled row only overwrites the
//    local one if the remote `updated_at` is newer (last-write-wins across
//    devices).
//  - Snapshots and checklist entries have no `updatedAt`; pull always
//    accepts the remote version for a `.synced` row there, since those rows
//    are effectively immutable/simple once created (see the doc comments on
//    the entities themselves).
//  - A `.synced` local row whose id no longer appears in the remote fetch
//    was deleted from another device (or another sync engine run) and gets
//    deleted locally too.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session, same caveat as SupabaseAuthService.swift -- the PostgREST query
//  builder shape (`.from(_:).select()/.upsert(_:)/.delete()`, `.eq(_:value:)`,
//  `.execute()`/`.execute().value`) is stable across recent supabase-swift
//  versions but should be the first thing checked against Xcode's
//  autocomplete once this builds. Same caveat applies to the Storage calls
//  added for Phase 3 (`client.storage.from(_:).upload(_:data:options:)`,
//  `.download(path:)`) -- verify those first too, they're newer code than
//  everything above and haven't been through even one build/fix cycle yet.
//
//  Phase 3 (photos): after the table sync above settles, `pushPendingImages`
//  and `pullMissingImages` reconcile image *bytes* the same way -- upload
//  local files Supabase doesn't have yet, download files a pulled/existing
//  entity references but that don't exist on this device (the reinstall
//  case). Image paths themselves aren't tracked in Postgres at all; they
//  ride along as plain string columns on the tables above (`imagePath`,
//  `coverImagePath`), so this only needs to look at what's already local.
//

import Foundation
import SwiftData
import Supabase
import WidgetKit

@ModelActor
actor SyncEngine {
    private var client: SupabaseClient { SupabaseClientProvider.shared }

    /// Runs a full push-then-pull pass for every table, for the given
    /// signed-in user. Throws on the first failure rather than attempting
    /// partial completion -- the tables' foreign keys mean a failure early
    /// in the parent-before-child order would just cascade into failures
    /// for every table after it anyway, so there's nothing to gain from
    /// pressing on.
    func sync(userID: UUID, imageStorage: ImageStorageService) async throws {
        try await pushHomes(userID: userID)
        try await pushRooms(userID: userID)
        try await pushItems(userID: userID)
        try await pushItemSnapshots(userID: userID)
        try await pushChecklists(userID: userID)
        try await pushChecklistEntries(userID: userID)

        try await pullHomes(userID: userID)
        try await pullRooms(userID: userID)
        try await pullItems(userID: userID)
        try await pullItemSnapshots(userID: userID)
        try await pullChecklists(userID: userID)
        try await pullChecklistEntries(userID: userID)

        // Images last -- by this point the local entity rows (and their
        // imagePath/coverImagePath columns) reflect the merged result of
        // both directions above, so this is looking at the final,
        // authoritative set of paths that ought to have a photo somewhere.
        let referencedPaths = try collectReferencedImagePaths()
        try await pushPendingImages(userID: userID, imageStorage: imageStorage, paths: referencedPaths)
        try await pullMissingImages(userID: userID, imageStorage: imageStorage, paths: referencedPaths)

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Push: Homes

    private func pushHomes(userID: UUID) async throws {
        let pendingUpsertStatus = SyncStatus.pendingUpsert.rawValue
        let upsertDescriptor = FetchDescriptor<HomeEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingUpsertStatus }
        )
        let toUpsert = try modelContext.fetch(upsertDescriptor)
        if !toUpsert.isEmpty {
            let rows = toUpsert.map { entity in
                HomeRow(id: entity.id, userID: userID, name: entity.name, createdAt: entity.createdAt, updatedAt: entity.updatedAt)
            }
            try await client.from("homes").upsert(rows).execute()
            for entity in toUpsert { entity.syncStatusRaw = SyncStatus.synced.rawValue }
        }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let deleteDescriptor = FetchDescriptor<HomeEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingDeleteStatus }
        )
        let toDelete = try modelContext.fetch(deleteDescriptor)
        for entity in toDelete {
            try await client.from("homes").delete().eq("id", value: entity.id).execute()
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    // MARK: - Push: Rooms

    private func pushRooms(userID: UUID) async throws {
        let pendingUpsertStatus = SyncStatus.pendingUpsert.rawValue
        let upsertDescriptor = FetchDescriptor<RoomEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingUpsertStatus }
        )
        let toUpsert = try modelContext.fetch(upsertDescriptor)
        if !toUpsert.isEmpty {
            let rows = toUpsert.map { entity in
                RoomRow(
                    id: entity.id, userID: userID, homeID: entity.homeID, name: entity.name,
                    iconName: entity.iconName, coverImagePath: entity.coverImagePath,
                    createdAt: entity.createdAt, updatedAt: entity.updatedAt
                )
            }
            try await client.from("rooms").upsert(rows).execute()
            for entity in toUpsert { entity.syncStatusRaw = SyncStatus.synced.rawValue }
        }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let deleteDescriptor = FetchDescriptor<RoomEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingDeleteStatus }
        )
        let toDelete = try modelContext.fetch(deleteDescriptor)
        for entity in toDelete {
            try await client.from("rooms").delete().eq("id", value: entity.id).execute()
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    // MARK: - Push: Items

    private func pushItems(userID: UUID) async throws {
        let pendingUpsertStatus = SyncStatus.pendingUpsert.rawValue
        let upsertDescriptor = FetchDescriptor<StoredItemEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingUpsertStatus }
        )
        let toUpsert = try modelContext.fetch(upsertDescriptor)
        if !toUpsert.isEmpty {
            let rows = toUpsert.map { entity in
                ItemRow(
                    id: entity.id, userID: userID, roomID: entity.roomID, name: entity.name,
                    category: entity.categoryRaw, notes: entity.notes, imagePath: entity.imagePath,
                    locationDescription: entity.locationDescription, lastSeenAt: entity.lastSeenAt,
                    createdAt: entity.createdAt, updatedAt: entity.updatedAt, isImportant: entity.isImportant
                )
            }
            try await client.from("items").upsert(rows).execute()
            for entity in toUpsert { entity.syncStatusRaw = SyncStatus.synced.rawValue }
        }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let deleteDescriptor = FetchDescriptor<StoredItemEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingDeleteStatus }
        )
        let toDelete = try modelContext.fetch(deleteDescriptor)
        for entity in toDelete {
            try await client.from("items").delete().eq("id", value: entity.id).execute()
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    // MARK: - Push: Item Snapshots

    private func pushItemSnapshots(userID: UUID) async throws {
        let pendingUpsertStatus = SyncStatus.pendingUpsert.rawValue
        let upsertDescriptor = FetchDescriptor<ItemSnapshotEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingUpsertStatus }
        )
        let toUpsert = try modelContext.fetch(upsertDescriptor)
        if !toUpsert.isEmpty {
            let rows = toUpsert.map { entity in
                ItemSnapshotRow(
                    id: entity.id, userID: userID, itemID: entity.itemID, roomID: entity.roomID,
                    imagePath: entity.imagePath, locationDescription: entity.locationDescription,
                    capturedAt: entity.capturedAt, confidence: entity.confidence, source: entity.sourceRaw
                )
            }
            try await client.from("item_snapshots").upsert(rows).execute()
            for entity in toUpsert { entity.syncStatusRaw = SyncStatus.synced.rawValue }
        }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let deleteDescriptor = FetchDescriptor<ItemSnapshotEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingDeleteStatus }
        )
        let toDelete = try modelContext.fetch(deleteDescriptor)
        for entity in toDelete {
            try await client.from("item_snapshots").delete().eq("id", value: entity.id).execute()
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    // MARK: - Push: Checklists

    private func pushChecklists(userID: UUID) async throws {
        let pendingUpsertStatus = SyncStatus.pendingUpsert.rawValue
        let upsertDescriptor = FetchDescriptor<ChecklistEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingUpsertStatus }
        )
        let toUpsert = try modelContext.fetch(upsertDescriptor)
        if !toUpsert.isEmpty {
            let rows = toUpsert.map { entity in
                ChecklistTableRow(
                    id: entity.id, userID: userID, name: entity.name, typeKind: entity.typeKind,
                    customLabel: entity.customLabel, createdAt: entity.createdAt, updatedAt: entity.updatedAt
                )
            }
            try await client.from("checklists").upsert(rows).execute()
            for entity in toUpsert { entity.syncStatusRaw = SyncStatus.synced.rawValue }
        }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let deleteDescriptor = FetchDescriptor<ChecklistEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingDeleteStatus }
        )
        let toDelete = try modelContext.fetch(deleteDescriptor)
        for entity in toDelete {
            try await client.from("checklists").delete().eq("id", value: entity.id).execute()
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    // MARK: - Push: Checklist Entries

    private func pushChecklistEntries(userID: UUID) async throws {
        let pendingUpsertStatus = SyncStatus.pendingUpsert.rawValue
        let upsertDescriptor = FetchDescriptor<ChecklistEntryEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingUpsertStatus }
        )
        let toUpsert = try modelContext.fetch(upsertDescriptor)
        if !toUpsert.isEmpty {
            let rows = toUpsert.map { entity in
                ChecklistEntryTableRow(
                    id: entity.id, userID: userID, checklistID: entity.checklistID, title: entity.title,
                    linkedItemID: entity.linkedItemID, locationDescription: entity.locationDescription,
                    isCompleted: entity.isCompleted, sortOrder: entity.sortOrder
                )
            }
            try await client.from("checklist_entries").upsert(rows).execute()
            for entity in toUpsert { entity.syncStatusRaw = SyncStatus.synced.rawValue }
        }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let deleteDescriptor = FetchDescriptor<ChecklistEntryEntity>(
            predicate: #Predicate { $0.syncStatusRaw == pendingDeleteStatus }
        )
        let toDelete = try modelContext.fetch(deleteDescriptor)
        for entity in toDelete {
            try await client.from("checklist_entries").delete().eq("id", value: entity.id).execute()
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    // MARK: - Pull: Homes

    private func pullHomes(userID: UUID) async throws {
        let remoteRows: [HomeRow] = try await client.from("homes").select().eq("user_id", value: userID).execute().value
        let remoteIDs = Set(remoteRows.map(\.id))
        let syncedStatus = SyncStatus.synced.rawValue

        let localDescriptor = FetchDescriptor<HomeEntity>()
        let localEntities = try modelContext.fetch(localDescriptor)
        let localByID = Dictionary(uniqueKeysWithValues: localEntities.map { ($0.id, $0) })

        for row in remoteRows {
            if let local = localByID[row.id] {
                guard local.syncStatusRaw == syncedStatus, row.updatedAt > local.updatedAt else { continue }
                local.name = row.name
                local.updatedAt = row.updatedAt
            } else {
                let entity = HomeEntity(id: row.id, name: row.name, createdAt: row.createdAt, updatedAt: row.updatedAt, syncStatusRaw: syncedStatus)
                modelContext.insert(entity)
            }
        }

        for local in localEntities where local.syncStatusRaw == syncedStatus && !remoteIDs.contains(local.id) {
            modelContext.delete(local)
        }
        try modelContext.save()
    }

    // MARK: - Pull: Rooms

    private func pullRooms(userID: UUID) async throws {
        let remoteRows: [RoomRow] = try await client.from("rooms").select().eq("user_id", value: userID).execute().value
        let remoteIDs = Set(remoteRows.map(\.id))
        let syncedStatus = SyncStatus.synced.rawValue

        let homesDescriptor = FetchDescriptor<HomeEntity>()
        let homesByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(homesDescriptor).map { ($0.id, $0) })

        let localDescriptor = FetchDescriptor<RoomEntity>()
        let localEntities = try modelContext.fetch(localDescriptor)
        let localByID = Dictionary(uniqueKeysWithValues: localEntities.map { ($0.id, $0) })

        for row in remoteRows {
            if let local = localByID[row.id] {
                guard local.syncStatusRaw == syncedStatus, row.updatedAt > local.updatedAt else { continue }
                local.homeID = row.homeID
                local.name = row.name
                local.iconName = row.iconName
                local.coverImagePath = row.coverImagePath
                local.updatedAt = row.updatedAt
                local.home = homesByID[row.homeID]
            } else {
                let entity = RoomEntity(
                    id: row.id, homeID: row.homeID, name: row.name, iconName: row.iconName,
                    coverImagePath: row.coverImagePath, createdAt: row.createdAt, updatedAt: row.updatedAt,
                    syncStatusRaw: syncedStatus
                )
                entity.home = homesByID[row.homeID]
                modelContext.insert(entity)
            }
        }

        for local in localEntities where local.syncStatusRaw == syncedStatus && !remoteIDs.contains(local.id) {
            modelContext.delete(local)
        }
        try modelContext.save()
    }

    // MARK: - Pull: Items

    private func pullItems(userID: UUID) async throws {
        let remoteRows: [ItemRow] = try await client.from("items").select().eq("user_id", value: userID).execute().value
        let remoteIDs = Set(remoteRows.map(\.id))
        let syncedStatus = SyncStatus.synced.rawValue

        let roomsDescriptor = FetchDescriptor<RoomEntity>()
        let roomsByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(roomsDescriptor).map { ($0.id, $0) })

        let localDescriptor = FetchDescriptor<StoredItemEntity>()
        let localEntities = try modelContext.fetch(localDescriptor)
        let localByID = Dictionary(uniqueKeysWithValues: localEntities.map { ($0.id, $0) })

        for row in remoteRows {
            if let local = localByID[row.id] {
                guard local.syncStatusRaw == syncedStatus, row.updatedAt > local.updatedAt else { continue }
                local.roomID = row.roomID
                local.name = row.name
                local.categoryRaw = row.category
                local.notes = row.notes
                local.imagePath = row.imagePath
                local.locationDescription = row.locationDescription
                local.lastSeenAt = row.lastSeenAt
                local.updatedAt = row.updatedAt
                local.isImportant = row.isImportant
                local.room = roomsByID[row.roomID]
            } else {
                let entity = StoredItemEntity(
                    id: row.id, roomID: row.roomID, name: row.name, categoryRaw: row.category,
                    notes: row.notes, imagePath: row.imagePath, locationDescription: row.locationDescription,
                    lastSeenAt: row.lastSeenAt, createdAt: row.createdAt, updatedAt: row.updatedAt,
                    isImportant: row.isImportant, syncStatusRaw: syncedStatus
                )
                entity.room = roomsByID[row.roomID]
                modelContext.insert(entity)
            }
        }

        for local in localEntities where local.syncStatusRaw == syncedStatus && !remoteIDs.contains(local.id) {
            modelContext.delete(local)
        }
        try modelContext.save()
    }

    // MARK: - Pull: Item Snapshots

    private func pullItemSnapshots(userID: UUID) async throws {
        let remoteRows: [ItemSnapshotRow] = try await client.from("item_snapshots").select().eq("user_id", value: userID).execute().value
        let remoteIDs = Set(remoteRows.map(\.id))
        let syncedStatus = SyncStatus.synced.rawValue

        let itemsDescriptor = FetchDescriptor<StoredItemEntity>()
        let itemsByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(itemsDescriptor).map { ($0.id, $0) })

        let localDescriptor = FetchDescriptor<ItemSnapshotEntity>()
        let localEntities = try modelContext.fetch(localDescriptor)
        let localByID = Dictionary(uniqueKeysWithValues: localEntities.map { ($0.id, $0) })

        for row in remoteRows {
            // No `updatedAt` to compare -- snapshots are treated as
            // immutable once synced, so an existing local `.synced` row is
            // simply left alone rather than re-written every pull.
            guard localByID[row.id] == nil else { continue }
            let entity = ItemSnapshotEntity(
                id: row.id, itemID: row.itemID, roomID: row.roomID, imagePath: row.imagePath,
                locationDescription: row.locationDescription, capturedAt: row.capturedAt,
                confidence: row.confidence, sourceRaw: row.source, syncStatusRaw: syncedStatus
            )
            entity.item = itemsByID[row.itemID]
            modelContext.insert(entity)
        }

        for local in localEntities where local.syncStatusRaw == syncedStatus && !remoteIDs.contains(local.id) {
            modelContext.delete(local)
        }
        try modelContext.save()
    }

    // MARK: - Pull: Checklists

    private func pullChecklists(userID: UUID) async throws {
        let remoteRows: [ChecklistTableRow] = try await client.from("checklists").select().eq("user_id", value: userID).execute().value
        let remoteIDs = Set(remoteRows.map(\.id))
        let syncedStatus = SyncStatus.synced.rawValue

        let localDescriptor = FetchDescriptor<ChecklistEntity>()
        let localEntities = try modelContext.fetch(localDescriptor)
        let localByID = Dictionary(uniqueKeysWithValues: localEntities.map { ($0.id, $0) })

        for row in remoteRows {
            if let local = localByID[row.id] {
                guard local.syncStatusRaw == syncedStatus, row.updatedAt > local.updatedAt else { continue }
                local.name = row.name
                local.typeKind = row.typeKind
                local.customLabel = row.customLabel
                local.updatedAt = row.updatedAt
            } else {
                let entity = ChecklistEntity(
                    id: row.id, name: row.name, typeKind: row.typeKind, customLabel: row.customLabel,
                    createdAt: row.createdAt, updatedAt: row.updatedAt, syncStatusRaw: syncedStatus
                )
                modelContext.insert(entity)
            }
        }

        for local in localEntities where local.syncStatusRaw == syncedStatus && !remoteIDs.contains(local.id) {
            modelContext.delete(local)
        }
        try modelContext.save()
    }

    // MARK: - Pull: Checklist Entries

    private func pullChecklistEntries(userID: UUID) async throws {
        let remoteRows: [ChecklistEntryTableRow] = try await client.from("checklist_entries").select().eq("user_id", value: userID).execute().value
        let remoteIDs = Set(remoteRows.map(\.id))
        let syncedStatus = SyncStatus.synced.rawValue

        let checklistsDescriptor = FetchDescriptor<ChecklistEntity>()
        let checklistsByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(checklistsDescriptor).map { ($0.id, $0) })
        let itemsDescriptor = FetchDescriptor<StoredItemEntity>()
        let itemsByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(itemsDescriptor).map { ($0.id, $0) })

        let localDescriptor = FetchDescriptor<ChecklistEntryEntity>()
        let localEntities = try modelContext.fetch(localDescriptor)
        let localByID = Dictionary(uniqueKeysWithValues: localEntities.map { ($0.id, $0) })

        for row in remoteRows {
            // No `updatedAt` on this table either -- see pullItemSnapshots.
            guard localByID[row.id] == nil else { continue }
            let entity = ChecklistEntryEntity(
                id: row.id, checklistID: row.checklistID, title: row.title, linkedItemID: row.linkedItemID,
                locationDescription: row.locationDescription, isCompleted: row.isCompleted,
                sortOrder: row.sortOrder, syncStatusRaw: syncedStatus
            )
            entity.checklist = checklistsByID[row.checklistID]
            if let linkedItemID = row.linkedItemID {
                entity.linkedItem = itemsByID[linkedItemID]
            }
            modelContext.insert(entity)
        }

        for local in localEntities where local.syncStatusRaw == syncedStatus && !remoteIDs.contains(local.id) {
            modelContext.delete(local)
        }
        try modelContext.save()
    }

    // MARK: - Images (Phase 3)

    /// Every non-nil `imagePath`/`coverImagePath` across the three entity
    /// types that have one, deduplicated. Not scoped by sync status --
    /// unlike the table rows, an image path itself has no local pending/
    /// synced state of its own (`ImageUploadTracker` tracks that
    /// separately), so every referenced path is a candidate for either
    /// push or pull depending on where the bytes are actually missing.
    private func collectReferencedImagePaths() throws -> Set<String> {
        var paths = Set<String>()

        let rooms = try modelContext.fetch(FetchDescriptor<RoomEntity>())
        for room in rooms {
            if let path = room.coverImagePath { paths.insert(path) }
        }

        let items = try modelContext.fetch(FetchDescriptor<StoredItemEntity>())
        for item in items {
            if let path = item.imagePath { paths.insert(path) }
        }

        let snapshots = try modelContext.fetch(FetchDescriptor<ItemSnapshotEntity>())
        for snapshot in snapshots {
            if let path = snapshot.imagePath { paths.insert(path) }
        }

        return paths
    }

    /// Uploads every referenced path that exists locally and hasn't been
    /// uploaded before. A path that's referenced but doesn't exist locally
    /// either (rare -- would mean it was never captured successfully) is
    /// silently skipped here; `pullMissingImages` only tries to recover
    /// paths that might exist *remotely*, which an upload-less path can't.
    private func pushPendingImages(userID: UUID, imageStorage: ImageStorageService, paths: Set<String>) async throws {
        for path in paths {
            guard !ImageUploadTracker.isUploaded(path) else { continue }
            guard await imageStorage.imageExists(at: path) else { continue }
            let data = try await imageStorage.loadImageData(from: path)
            try await client.storage.from("item-images").upload(
                "\(userID)/\(path)",
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
            ImageUploadTracker.markUploaded(path)
        }
    }

    /// Downloads any referenced path that doesn't exist locally -- the
    /// reinstall case, where the entity rows came back via the table pull
    /// above but the image bytes never lived anywhere but the old install's
    /// local disk. Best-effort: a path that was never actually uploaded
    /// (e.g. the user deleted the app before their first sync ever ran)
    /// simply fails the download and is left missing, same as today.
    private func pullMissingImages(userID: UUID, imageStorage: ImageStorageService, paths: Set<String>) async throws {
        for path in paths {
            guard await imageStorage.imageExists(at: path) == false else { continue }
            guard let data = try? await client.storage.from("item-images").download(path: "\(userID)/\(path)") else {
                continue
            }
            try? await imageStorage.restoreImageData(data, at: path)
            ImageUploadTracker.markUploaded(path)
        }
    }
}
