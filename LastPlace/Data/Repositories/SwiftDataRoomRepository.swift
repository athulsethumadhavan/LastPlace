//
//  SwiftDataRoomRepository.swift
//  LastPlace
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataRoomRepository: RoomRepository {
    func fetchRooms(homeID: UUID) async throws -> [Room] {
        let target = homeID
        let descriptor = FetchDescriptor<RoomEntity>(
            predicate: #Predicate { $0.homeID == target },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        do {
            return try modelContext.fetch(descriptor).map(RoomMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    func fetchRoom(roomID: UUID) async throws -> Room {
        let entity = try fetchEntity(id: roomID)
        return RoomMapper.toDomain(entity)
    }

    func create(_ room: Room) async throws -> Room {
        let validated = try room.validated()
        let entity = RoomMapper.toEntity(validated)
        modelContext.insert(entity)
        try saveOrThrow()
        return RoomMapper.toDomain(entity)
    }

    func update(_ room: Room) async throws -> Room {
        let validated = try room.validated()
        let entity = try fetchEntity(id: validated.id)
        RoomMapper.apply(validated, to: entity)
        try saveOrThrow()
        return RoomMapper.toDomain(entity)
    }

    func delete(roomID: UUID) async throws {
        let entity = try fetchEntity(id: roomID)
        modelContext.delete(entity)
        try saveOrThrow()
    }

    private func fetchEntity(id: UUID) throws -> RoomEntity {
        let target = id
        let descriptor = FetchDescriptor<RoomEntity>(predicate: #Predicate { $0.id == target })
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
