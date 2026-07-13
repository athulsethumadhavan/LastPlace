//
//  ScanSessionMapper.swift
//  LastPlace
//

import Foundation

enum ScanSessionMapper {
    static func toDomain(_ entity: ScanSessionEntity) -> ScanSession {
        ScanSession(
            id: entity.id,
            roomID: entity.roomID,
            startedAt: entity.startedAt,
            completedAt: entity.completedAt,
            capturedImagePaths: entity.capturedImagePaths,
            status: ScanSessionStatus(rawValue: entity.statusRaw) ?? .inProgress
        )
    }

    static func toEntity(_ session: ScanSession) -> ScanSessionEntity {
        ScanSessionEntity(
            id: session.id,
            roomID: session.roomID,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            capturedImagePaths: session.capturedImagePaths,
            statusRaw: session.status.rawValue
        )
    }
}
