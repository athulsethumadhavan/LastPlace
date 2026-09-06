//
//  RoomMapper.swift
//  LastPlace
//

import Foundation

enum RoomMapper {
    static func toDomain(_ entity: RoomEntity) -> Room {
        Room(
            id: entity.id,
            homeID: entity.homeID,
            name: entity.name,
            iconName: entity.iconName,
            coverImagePath: entity.coverImagePath,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    static func toEntity(_ room: Room) -> RoomEntity {
        RoomEntity(
            id: room.id,
            homeID: room.homeID,
            name: room.name,
            iconName: room.iconName,
            coverImagePath: room.coverImagePath,
            createdAt: room.createdAt,
            updatedAt: room.updatedAt
        )
    }

    static func apply(_ room: Room, to entity: RoomEntity) {
        entity.homeID = room.homeID
        entity.name = room.name
        entity.iconName = room.iconName
        entity.coverImagePath = room.coverImagePath
        entity.updatedAt = room.updatedAt
    }
}
