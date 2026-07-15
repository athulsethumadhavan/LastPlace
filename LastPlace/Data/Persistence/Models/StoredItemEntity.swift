//
//  StoredItemEntity.swift
//  LastPlace
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
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
