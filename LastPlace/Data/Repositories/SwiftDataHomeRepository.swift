//
//  SwiftDataHomeRepository.swift
//  LastPlace
//

import Foundation
import SwiftData

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

    func fetchDefaultHome() async throws -> Home {
        let descriptor = FetchDescriptor<HomeEntity>(sortBy: [SortDescriptor(\.createdAt)])
        do {
            if let first = try modelContext.fetch(descriptor).first {
                return HomeMapper.toDomain(first)
            }
            let now = Date()
            let entity = HomeEntity(id: UUID(), name: "My Home", createdAt: now, updatedAt: now)
            modelContext.insert(entity)
            try modelContext.save()
            return HomeMapper.toDomain(entity)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    func create(name: String) async throws -> Home {
        let draft = try Home(name: name).validated()
        let entity = HomeMapper.toEntity(draft)
        modelContext.insert(entity)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        return HomeMapper.toDomain(entity)
    }

    func rename(homeID: UUID, to name: String) async throws -> Home {
        let entity = try fetchEntity(id: homeID)
        var domain = HomeMapper.toDomain(entity)
        domain.name = name
        domain.updatedAt = Date()
        let validated = try domain.validated()
        HomeMapper.apply(validated, to: entity)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        return HomeMapper.toDomain(entity)
    }

    func delete(homeID: UUID) async throws {
        let entity = try fetchEntity(id: homeID)
        modelContext.delete(entity)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
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
}
