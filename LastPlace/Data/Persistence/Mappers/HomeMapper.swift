//
//  HomeMapper.swift
//  LastPlace
//

import Foundation

enum HomeMapper {
    static func toDomain(_ entity: HomeEntity) -> Home {
        Home(
            id: entity.id,
            name: entity.name,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    static func toEntity(_ home: Home) -> HomeEntity {
        HomeEntity(
            id: home.id,
            name: home.name,
            createdAt: home.createdAt,
            updatedAt: home.updatedAt
        )
    }

    static func apply(_ home: Home, to entity: HomeEntity) {
        entity.name = home.name
        entity.updatedAt = home.updatedAt
    }
}
