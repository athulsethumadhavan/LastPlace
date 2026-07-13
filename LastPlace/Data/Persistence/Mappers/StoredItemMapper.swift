//
//  StoredItemMapper.swift
//  LastPlace
//

import Foundation

enum StoredItemMapper {
    static func toDomain(_ entity: StoredItemEntity) -> StoredItem {
        StoredItem(
            id: entity.id,
            roomID: entity.roomID,
            name: entity.name,
            category: ItemCategory(rawValue: entity.categoryRaw) ?? .other,
            notes: entity.notes,
            imagePath: entity.imagePath,
            locationDescription: entity.locationDescription,
            lastSeenAt: entity.lastSeenAt,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            isImportant: entity.isImportant
        )
    }

    static func toEntity(_ item: StoredItem) -> StoredItemEntity {
        StoredItemEntity(
            id: item.id,
            roomID: item.roomID,
            name: item.name,
            categoryRaw: item.category.rawValue,
            notes: item.notes,
            imagePath: item.imagePath,
            locationDescription: item.locationDescription,
            lastSeenAt: item.lastSeenAt,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            isImportant: item.isImportant
        )
    }

    static func apply(_ item: StoredItem, to entity: StoredItemEntity) {
        entity.roomID = item.roomID
        entity.name = item.name
        entity.categoryRaw = item.category.rawValue
        entity.notes = item.notes
        entity.imagePath = item.imagePath
        entity.locationDescription = item.locationDescription
        entity.lastSeenAt = item.lastSeenAt
        entity.updatedAt = item.updatedAt
        entity.isImportant = item.isImportant
    }
}
