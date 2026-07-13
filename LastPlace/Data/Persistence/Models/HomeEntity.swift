//
//  HomeEntity.swift
//  LastPlace
//
//  SwiftData persistence model. Confined to the Data layer — never returned
//  outside of it. Mappers convert to/from the `Home` domain entity.
//

import Foundation
import SwiftData

@Model
final class HomeEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
