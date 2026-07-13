//
//  StoredItemEntity.swift
//  LastPlace
//

import Foundation
import SwiftData

@Model
final class StoredItemEntity {
    @Attribute(.unique) var id: UUID
    var roomID: UUID
    var name: String
    /// Raw value of `ItemCategory` — stored as `String` so #Predicate can match on it.
    var categoryRaw: String
    var notes: String?
    var imagePath: String?
    var locationDescription: String
    var lastSeenAt: Date
    var createdAt: Date
    var updatedAt: Date
    var isImportant: Bool

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
