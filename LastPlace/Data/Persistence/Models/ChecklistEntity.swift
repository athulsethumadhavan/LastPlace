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
//  `entries` is a `@Relationship` so a shared checklist brings its entries
//  along — see the note on `HomeEntity.rooms` for the general reasoning.
//  Checklists aren't scoped to a `Home` in this pass (there's no `homeID`
//  concept on `Checklist` today, and adding one would ripple into the
//  domain layer and use cases beyond what this persistence-only migration
//  is meant to touch) — they stay their own independent share root rather
//  than riding along inside a shared Home.
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

    @Relationship(deleteRule: .cascade, inverse: \ChecklistEntryEntity.checklist)
    var entries: [ChecklistEntryEntity]? = []

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
