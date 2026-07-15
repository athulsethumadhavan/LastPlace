//
//  SwiftDataScanRepository.swift
//  LastPlace
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataScanRepository: ScanRepository {
    /// Without `@Attribute(.unique)` (unsupported by CloudKit-backed
    /// SwiftData) nothing at the persistence layer stops a second insert
    /// with the same `id` from creating a duplicate row, so this checks
    /// first and updates in place if one is already there.
    func startSession(roomID: UUID) async throws -> ScanSession {
        let session = ScanSession(roomID: roomID)
        if let existing = try findEntity(id: session.id) {
            ScanSessionMapper.apply(session, to: existing)
            try saveOrThrow()
            return ScanSessionMapper.toDomain(existing)
        }
        let entity = ScanSessionMapper.toEntity(session)
        modelContext.insert(entity)
        try saveOrThrow()
        return ScanSessionMapper.toDomain(entity)
    }

    func fetchSession(id: UUID) async throws -> ScanSession {
        let entity = try fetchEntity(id: id)
        return ScanSessionMapper.toDomain(entity)
    }

    func appendImage(sessionID: UUID, imagePath: String) async throws -> ScanSession {
        let entity = try fetchEntity(id: sessionID)
        guard entity.statusRaw == ScanSessionStatus.inProgress.rawValue else {
            throw RepositoryError.invalidState(reason: "Scan session is not in progress.")
        }
        entity.capturedImagePaths.append(imagePath)
        try saveOrThrow()
        return ScanSessionMapper.toDomain(entity)
    }

    func complete(sessionID: UUID) async throws -> ScanSession {
        let entity = try fetchEntity(id: sessionID)
        entity.statusRaw = ScanSessionStatus.completed.rawValue
        entity.completedAt = Date()
        try saveOrThrow()
        return ScanSessionMapper.toDomain(entity)
    }

    func cancel(sessionID: UUID) async throws {
        let entity = try fetchEntity(id: sessionID)
        entity.statusRaw = ScanSessionStatus.cancelled.rawValue
        entity.completedAt = Date()
        try saveOrThrow()
    }

    private func fetchEntity(id: UUID) throws -> ScanSessionEntity {
        let target = id
        let descriptor = FetchDescriptor<ScanSessionEntity>(predicate: #Predicate { $0.id == target })
        do {
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound
            }
            return entity
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Plain existence check used by `startSession`'s dedupe guard — `nil`
    /// means not found, unlike `fetchEntity` which throws `.notFound`.
    private func findEntity(id: UUID) throws -> ScanSessionEntity? {
        let target = id
        let descriptor = FetchDescriptor<ScanSessionEntity>(predicate: #Predicate { $0.id == target })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }
}
