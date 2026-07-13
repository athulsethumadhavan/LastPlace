//
//  ItemSnapshotMapper.swift
//  LastPlace
//

import Foundation

enum ItemSnapshotMapper {
    static func toDomain(_ entity: ItemSnapshotEntity) -> ItemSnapshot {
        ItemSnapshot(
            id: entity.id,
            itemID: entity.itemID,
            roomID: entity.roomID,
            imagePath: entity.imagePath,
            locationDescription: entity.locationDescription,
            capturedAt: entity.capturedAt,
            confidence: entity.confidence,
            source: SnapshotSource(rawValue: entity.sourceRaw) ?? .manual
        )
    }

    static func toEntity(_ snapshot: ItemSnapshot) -> ItemSnapshotEntity {
        ItemSnapshotEntity(
            id: snapshot.id,
            itemID: snapshot.itemID,
            roomID: snapshot.roomID,
            imagePath: snapshot.imagePath,
            locationDescription: snapshot.locationDescription,
            capturedAt: snapshot.capturedAt,
            confidence: snapshot.confidence,
            sourceRaw: snapshot.source.rawValue
        )
    }
}
