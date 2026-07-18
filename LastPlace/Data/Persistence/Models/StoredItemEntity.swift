//
//  StoredItemEntity.swift
//  LastPlace
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
//
//  `room` and `snapshots` are `@Relationship`s alongside the existing flat
//  `roomID` — see the note on `HomeEntity.rooms` for why both exist.
//  `SwiftDataItemRepository` keeps `room` in sync whenever it writes
//  `roomID`; `SwiftDataSnapshotRepository` does the same for `snapshots`/`item`.
//

import Foundation
import SwiftData

@Model
final class StoredItemEntity {
    var id: UUID = UUID()
    var roomID: UUID = UUID()
    var name: String = ""
    /// Raw value of `ItemCategory` — stored as `String` so #Predicate can match on it.
    var categoryRaw: String = ""
    var notes: String?
    var imagePath: String?
    var locationDescription: String = ""
    var lastSeenAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isImportant: Bool = false

    var room: RoomEntity?

    @Relationship(deleteRule: .cascade, inverse: \ItemSnapshotEntity.item)
    var snapshots: [ItemSnapshotEntity]? = []

    /// Inverse side of `ChecklistEntryEntity.linkedItem`. CloudKit-backed
    /// SwiftData rejects any relationship that doesn't have an inverse on
    /// both sides, even ones that are conceptually one-directional — this
    /// is what "CloudKit integration requires that all relationships have
    /// an inverse" was pointing at. Not read anywhere in the app; it
    /// exists purely to satisfy that constraint.
    var linkedFromChecklistEntries: [ChecklistEntryEntity]? = []

    init(
        id: UUID,
        roomID: UUID,
        name: String,
        categoryRaw: String,
        notes: String?,
        imagePath: String?,
        locationDescription: String,
        lastSeenAt: Date,
        createdAt: Date,
        updatedAt: Date,
        isImportant: Bool
    ) {
        self.id = id
        self.roomID = roomID
        self.name = name
        self.categoryRaw = categoryRaw
        self.notes = notes
        self.imagePath = imagePath
        self.locationDescription = locationDescription
        self.lastSeenAt = lastSeenAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isImportant = isImportant
    }
}
