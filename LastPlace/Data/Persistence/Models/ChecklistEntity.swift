//
//  ChecklistEntity.swift
//  LastPlace
//
//  `ChecklistType` has an associated value on the `custom` case, so it's stored
//  as a discriminator + optional label and reassembled by the mapper.
//

import Foundation
import SwiftData

@Model
final class ChecklistEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeKind: String
    var customLabel: String?
    var createdAt: Date
    var updatedAt: Date

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
