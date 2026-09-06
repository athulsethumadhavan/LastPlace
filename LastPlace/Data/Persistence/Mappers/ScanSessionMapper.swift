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

    /// Used by the repository's create-path dedupe guard: if a session with
    /// this `id` already exists (e.g. a CloudKit-merge race), overwrite it in
    /// place instead of inserting a second row.
    static func apply(_ session: ScanSession, to entity: ScanSessionEntity) {
        entity.roomID = session.roomID
        entity.startedAt = session.startedAt
        entity.completedAt = session.completedAt
        entity.capturedImagePaths = session.capturedImagePaths
        entity.statusRaw = session.status.rawValue
    }
}
