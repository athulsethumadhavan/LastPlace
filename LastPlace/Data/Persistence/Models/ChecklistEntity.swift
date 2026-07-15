//
//  ChecklistEntity.swift
//  LastPlace
//
//  `ChecklistType` has an associated value on the `custom` case, so it's stored
//  as a discriminator + optional label and reassembled by the mapper.
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
//

import Foundation
import SwiftData

@Model
final class ChecklistEntity {
    var id: UUID = UUID()
    var name: String = ""
    var typeKind: String = ""
    var customLabel: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID,
        name: String,
        typeKind: String,
        customLabel: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.typeKind = typeKind
        self.customLabel = customLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
