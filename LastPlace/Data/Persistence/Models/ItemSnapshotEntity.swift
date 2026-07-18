//
//  ItemSnapshotEntity.swift
//  LastPlace
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
//
//  `item` is a `@Relationship` alongside the existing flat `itemID`/`roomID`
//  — see the note on `HomeEntity.rooms` for why both exist.
//  `SwiftDataSnapshotRepository` keeps it in sync.
//

import Foundation
import SwiftData

@Model
final class ItemSnapshotEntity {
    var id: UUID = UUID()
    var itemID: UUID = UUID()
    var roomID: UUID = UUID()
    var imagePath: String?
    var locationDescription: String = ""
    var capturedAt: Date = Date()
    var confidence: Double = 0
    var sourceRaw: String = ""

    var item: StoredItemEntity?

    init(
        id: UUID,
        itemID: UUID,
        roomID: UUID,
        imagePath: String?,
        locationDescription: String,
        capturedAt: Date,
        confidence: Double,
        sourceRaw: String
    ) {
        self.id = id
        self.itemID = itemID
        self.roomID = roomID
        self.imagePath = imagePath
        self.locationDescription = locationDescription
        self.capturedAt = capturedAt
        self.confidence = confidence
        self.sourceRaw = sourceRaw
    }
}
