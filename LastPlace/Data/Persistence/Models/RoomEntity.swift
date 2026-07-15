//
//  RoomEntity.swift
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
final class RoomEntity {
    var id: UUID = UUID()
    var homeID: UUID = UUID()
    var name: String = ""
    var iconName: String = ""
    var coverImagePath: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID,
        homeID: UUID,
        name: String,
        iconName: String,
        coverImagePath: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.homeID = homeID
        self.name = name
        self.iconName = iconName
        self.coverImagePath = coverImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
