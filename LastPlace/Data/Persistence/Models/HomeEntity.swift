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

import Foundation
import SwiftData

@Model
final class HomeEntity {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
