//
//  SwiftDataScanRepository.swift
//  LastPlace
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataScanRepository: ScanRepository {
    func startSession(roomID: UUID) async throws -> ScanSession {
        let session = ScanSession(roomID: roomID)
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

    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }
}
