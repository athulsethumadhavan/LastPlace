//
//  SwiftDataRoomRepository.swift
//  LastPlace
//

import Foundation
import SwiftData
import WidgetKit

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

    /// Without `@Attribute(.unique)` (unsupported by CloudKit-backed
    /// SwiftData) nothing at the persistence layer stops a second insert
    /// with the same `id` from creating a duplicate row, so this checks
    /// first and updates in place if one is already there.
    func create(_ room: Room) async throws -> Room {
        let validated = try room.validated()
        if let existing = try findEntity(id: validated.id) {
            RoomMapper.apply(validated, to: existing)
            existing.syncStatusRaw = SyncStatus.pendingUpsert.rawValue
            try linkHome(for: existing)
            try saveOrThrow()
            return RoomMapper.toDomain(existing)
        }
        let entity = RoomMapper.toEntity(validated)
        modelContext.insert(entity)
        try linkHome(for: entity)
        try saveOrThrow()
        return RoomMapper.toDomain(entity)
    }

    func update(_ room: Room) async throws -> Room {
        let validated = try room.validated()
        let entity = try fetchEntity(id: validated.id)
        RoomMapper.apply(validated, to: entity)
        entity.syncStatusRaw = SyncStatus.pendingUpsert.rawValue
        try linkHome(for: entity)
        try saveOrThrow()
        return RoomMapper.toDomain(entity)
    }

    /// See the doc comment on `SwiftDataHomeRepository.delete` for the
    /// hard-delete-vs-`.pendingDelete` reasoning.
    func delete(roomID: UUID) async throws {
        let entity = try fetchEntity(id: roomID)
        if entity.syncStatusRaw == SyncStatus.pendingUpsert.rawValue {
            modelContext.delete(entity)
        } else {
            entity.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        }
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

    /// Plain existence check used by `create`'s dedupe guard — `nil` means
    /// not found, unlike `fetchEntity` which throws `.notFound`.
    private func findEntity(id: UUID) throws -> RoomEntity? {
        let target = id
        let descriptor = FetchDescriptor<RoomEntity>(predicate: #Predicate { $0.id == target })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Keeps the `home` relationship pointer in sync with the flat `homeID`
    /// field (see the doc comment on `HomeEntity.rooms`). A no-op if it's
    /// already correct, so this is cheap to call unconditionally on every
    /// write.
    private func linkHome(for entity: RoomEntity) throws {
        guard entity.home?.id != entity.homeID else { return }
        let target = entity.homeID
        let descriptor = FetchDescriptor<HomeEntity>(predicate: #Predicate { $0.id == target })
        do {
            entity.home = try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Reloading widget timelines on every save is a bit coarse, but
    /// `WidgetCenter` calls are cheap and system-throttled, so precision
    /// isn't worth chasing here.
    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
