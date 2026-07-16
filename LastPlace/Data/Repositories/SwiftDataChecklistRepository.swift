//
//  SwiftDataChecklistRepository.swift
//  LastPlace
//

import Foundation
import SwiftData
import WidgetKit

@ModelActor
actor SwiftDataChecklistRepository: ChecklistRepository {
    func fetchChecklists() async throws -> [Checklist] {
        let descriptor = FetchDescriptor<ChecklistEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor).map(ChecklistMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    func fetchChecklist(id: UUID) async throws -> Checklist {
        let entity = try fetchChecklistEntity(id: id)
        return ChecklistMapper.toDomain(entity)
    }

    func fetchEntries(checklistID: UUID) async throws -> [ChecklistEntry] {
        let target = checklistID
        let descriptor = FetchDescriptor<ChecklistEntryEntity>(
            predicate: #Predicate { $0.checklistID == target },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            return try modelContext.fetch(descriptor).map(ChecklistEntryMapper.toDomain)
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Without `@Attribute(.unique)` (unsupported by CloudKit-backed
    /// SwiftData) nothing at the persistence layer stops a second insert
    /// with the same `id` from creating a duplicate row, so this checks
    /// first and updates in place if one is already there.
    func create(_ checklist: Checklist) async throws -> Checklist {
        let validated = try checklist.validated()
        if let existing = try findChecklistEntity(id: validated.id) {
            ChecklistMapper.apply(validated, to: existing)
            try saveOrThrow()
            return ChecklistMapper.toDomain(existing)
        }
        let entity = ChecklistMapper.toEntity(validated)
        modelContext.insert(entity)
        try saveOrThrow()
        return ChecklistMapper.toDomain(entity)
    }

    /// Same dedupe-guard reasoning as `create` above.
    func addEntry(_ entry: ChecklistEntry) async throws -> ChecklistEntry {
        let validated = try entry.validated()
        _ = try fetchChecklistEntity(id: validated.checklistID)
        if let existing = try findEntryEntity(id: validated.id) {
            ChecklistEntryMapper.apply(validated, to: existing)
            try saveOrThrow()
            return ChecklistEntryMapper.toDomain(existing)
        }
        let entity = ChecklistEntryMapper.toEntity(validated)
        modelContext.insert(entity)
        try saveOrThrow()
        return ChecklistEntryMapper.toDomain(entity)
    }

    func updateEntry(_ entry: ChecklistEntry) async throws -> ChecklistEntry {
        let validated = try entry.validated()
        let entity = try fetchEntryEntity(id: validated.id)
        ChecklistEntryMapper.apply(validated, to: entity)
        try saveOrThrow()
        return ChecklistEntryMapper.toDomain(entity)
    }

    func toggle(entryID: UUID) async throws -> ChecklistEntry {
        let entity = try fetchEntryEntity(id: entryID)
        entity.isCompleted.toggle()
        try saveOrThrow()
        return ChecklistEntryMapper.toDomain(entity)
    }

    func resetChecklist(id: UUID) async throws {
        let target = id
        let descriptor = FetchDescriptor<ChecklistEntryEntity>(
            predicate: #Predicate { $0.checklistID == target }
        )
        do {
            let entities = try modelContext.fetch(descriptor)
            for entity in entities {
                entity.isCompleted = false
            }
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        try saveOrThrow()
    }

    func delete(checklistID: UUID) async throws {
        let target = checklistID
        let checklist = try fetchChecklistEntity(id: checklistID)
        let entryDescriptor = FetchDescriptor<ChecklistEntryEntity>(
            predicate: #Predicate { $0.checklistID == target }
        )
        do {
            let entries = try modelContext.fetch(entryDescriptor)
            for entry in entries {
                modelContext.delete(entry)
            }
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        modelContext.delete(checklist)
        try saveOrThrow()
    }

    func delete(entryID: UUID) async throws {
        let entity = try fetchEntryEntity(id: entryID)
        modelContext.delete(entity)
        try saveOrThrow()
    }

    private func fetchChecklistEntity(id: UUID) throws -> ChecklistEntity {
        let target = id
        let descriptor = FetchDescriptor<ChecklistEntity>(predicate: #Predicate { $0.id == target })
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

    private func fetchEntryEntity(id: UUID) throws -> ChecklistEntryEntity {
        let target = id
        let descriptor = FetchDescriptor<ChecklistEntryEntity>(predicate: #Predicate { $0.id == target })
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
    /// not found, unlike `fetchChecklistEntity` which throws `.notFound`.
    private func findChecklistEntity(id: UUID) throws -> ChecklistEntity? {
        let target = id
        let descriptor = FetchDescriptor<ChecklistEntity>(predicate: #Predicate { $0.id == target })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Plain existence check used by `addEntry`'s dedupe guard — `nil` means
    /// not found, unlike `fetchEntryEntity` which throws `.notFound`.
    private func findEntryEntity(id: UUID) throws -> ChecklistEntryEntity? {
        let target = id
        let descriptor = FetchDescriptor<ChecklistEntryEntity>(predicate: #Predicate { $0.id == target })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
    }

    /// Reloading widget timelines on every save is a bit coarse, but
    /// `WidgetCenter` calls are cheap and system-throttled, so precision
    /// isn't worth chasing here — the Checklist Progress widget wants to
    /// catch every toggle anyway.
    private func saveOrThrow() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(underlying: error.localizedDescription)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
