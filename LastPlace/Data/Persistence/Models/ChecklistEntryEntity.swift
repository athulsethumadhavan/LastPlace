//
//  ChecklistEntryEntity.swift
//  LastPlace
//
//  `locationDescription` was added after the initial schema — it's Optional
//  so SwiftData's lightweight migration can add the column without a
//  migration plan. Only meaningful for unlinked entries; see the domain
//  entity's doc comment.
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
//
//  `checklist` is a `@Relationship` alongside the existing flat
//  `checklistID` — see the note on `HomeEntity.rooms` for why both exist.
//  `linkedItem` is also a relationship (`.nullify`, not owning — this entry
//  merely references an item that lives in a room elsewhere, so deleting
//  the item should unlink it rather than deleting the entry).
//  `SwiftDataChecklistRepository` keeps both in sync.
//

import Foundation
import SwiftData

@Model
final class ChecklistEntryEntity {
    var id: UUID = UUID()
    var checklistID: UUID = UUID()
    var title: String = ""
    var linkedItemID: UUID?
    var locationDescription: String?
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    /// See `SyncStatus` on `HomeEntity`. No `updatedAt` here (like snapshots),
    /// so `SyncEngine`'s pull always lets a local `.pendingUpsert` row win
    /// over whatever's on the server rather than comparing timestamps.
    var syncStatusRaw: String = SyncStatus.pendingUpsert.rawValue

    var checklist: ChecklistEntity?

    @Relationship(deleteRule: .nullify, inverse: \StoredItemEntity.linkedFromChecklistEntries)
    var linkedItem: StoredItemEntity?

    init(
        id: UUID,
        checklistID: UUID,
        title: String,
        linkedItemID: UUID?,
        locationDescription: String? = nil,
        isCompleted: Bool,
        sortOrder: Int,
        syncStatusRaw: String = SyncStatus.pendingUpsert.rawValue
    ) {
        self.id = id
        self.checklistID = checklistID
        self.title = title
        self.linkedItemID = linkedItemID
        self.locationDescription = locationDescription
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.syncStatusRaw = syncStatusRaw
    }
}
