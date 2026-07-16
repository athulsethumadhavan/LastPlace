//
//  SwiftDataHomeRepository.swift
//  LastPlace
//

import Foundation
import SwiftData
import WidgetKit

@ModelActor
actor SwiftDataHomeRepository: HomeRepository {
    func fetchHomes() async throws -> [Home] {
        let descriptor = FetchDescriptor<HomeEntity>(sortBy: [SortDescriptor(\.createdAt)])
        do {
            let entities = try modelContext.fetch(descriptor)
            return entities.map(HomeMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Sorted + "take the oldest" rather than "take any" so that if CloudKit
    /// sync ever lands two independently-created default homes (e.g. two
    /// devices each bootstrapped one while offline before their first sync),
    /// every device converges on the same one deterministically. It doesn't
    /// merge the "loser" home's rooms in automatically — that's a rarer edge
    /// case left as a known limitation rather than a full merge tool.
    func fetchDefaultHome() async throws -> Home {
        let descriptor = FetchDescriptor<HomeEntity>(sortBy: [SortDescriptor(\.createdAt)])
        do {
            if let first = try modelContext.fetch(descriptor).first {
                return HomeMapper.toDomain(first)
            }
            let now = Date()
            let entity = HomeEntity(id: UUID(), name: "My Home", createdAt: now, updatedAt: now)
            modelContext.insert(entity)
            try saveOrThrow()
            return HomeMapper.toDomain(entity)
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Without `@Attribute(.unique)` (unsupported by CloudKit-backed
    /// SwiftData) nothing at the persistence layer stops a second insert
    /// with the same `id` from creating a duplicate row, so this checks
    /// first and updates in place if one is already there.
    func create(name: String) async throws -> Home {
        let draft = try Home(name: name).validated()
        if let existing = try findEntity(id: draft.id) {
            HomeMapper.apply(draft, to: existing)
            try saveOrThrow()
            return HomeMapper.toDomain(existing)
        }
        let entity = HomeMapper.toEntity(draft)
        modelContext.insert(entity)
        try saveOrThrow()
        return HomeMapper.toDomain(entity)
    }

    func rename(homeID: UUID, to name: String) async throws -> Home {
        let entity = try fetchEntity(id: homeID)
        var domain = HomeMapper.toDomain(entity)
        domain.name = name
        domain.updatedAt = Date()
        let validated = try domain.validated()
        HomeMapper.apply(validated, to: entity)
        try saveOrThrow()
        return HomeMapper.toDomain(entity)
    }

    func delete(homeID: UUID) async throws {
        let entity = try fetchEntity(id: homeID)
        modelContext.delete(entity)
        try saveOrThrow()
    }

    private func fetchEntity(id: UUID) throws -> HomeEntity {
        let target = id
        let descriptor = FetchDescriptor<HomeEntity>(predicate: #Predicate { $0.id == target })
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
    private func findEntity(id: UUID) throws -> HomeEntity? {
        let target = id
        let descriptor = FetchDescriptor<HomeEntity>(predicate: #Predicate { $0.id == target })
        return try modelContext.fetch(descriptor).first
    }

    /// Reloading widget timelines on every save is a bit coarse (any home
    /// rename triggers it too, not just changes the widgets actually show),
    /// but `WidgetCenter` calls are cheap and system-throttled, so precision
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
