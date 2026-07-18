//
//  HomeEntity.swift
//  LastPlace
//
//  SwiftData persistence model. Confined to the Data layer — never returned
//  outside of it. Mappers convert to/from the `Home` domain entity.
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every stored property has a default
//  value, which CloudKit's schema requires even though `init` always sets
//  them explicitly.
//
//  `rooms` is a `@Relationship`, not just the flat `homeID` every room also
//  carries — CloudKit sharing determines what travels together in a share
//  by walking the relationship graph, not by matching foreign-key-style UUID
//  fields, so this exists purely so a shared Home brings its rooms (and,
//  transitively, their items) along. `homeID`-based queries elsewhere are
//  untouched and remain the source of truth for everyday fetches; this is
//  additive. Existing rooms created before this relationship existed get
//  their `home` pointer backfilled once by
//  `SwiftDataContainerFactory.backfillRelationships`.
//

import Foundation
import SwiftData

@Model
final class HomeEntity {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RoomEntity.home)
    var rooms: [RoomEntity]? = []

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
