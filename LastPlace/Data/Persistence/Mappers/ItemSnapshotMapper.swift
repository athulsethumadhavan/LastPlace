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

    /// Used by the repository's create-path dedupe guard: if a snapshot with
    /// this `id` already exists (e.g. a CloudKit-merge race), overwrite it in
    /// place instead of inserting a second row.
    static func apply(_ snapshot: ItemSnapshot, to entity: ItemSnapshotEntity) {
        entity.itemID = snapshot.itemID
        entity.roomID = snapshot.roomID
        entity.imagePath = snapshot.imagePath
        entity.locationDescription = snapshot.locationDescription
        entity.capturedAt = snapshot.capturedAt
        entity.confidence = snapshot.confidence
        entity.sourceRaw = snapshot.source.rawValue
    }
}
