//
//  RoomEntity.swift
//  LastPlace
//

import Foundation
import SwiftData

@Model
final class RoomEntity {
    @Attribute(.unique) var id: UUID
    var homeID: UUID
    var name: String
    var iconName: String
    var coverImagePath: String?
    var createdAt: Date
    var updatedAt: Date

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
