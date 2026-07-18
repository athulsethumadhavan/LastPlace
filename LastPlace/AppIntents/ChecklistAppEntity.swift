//
//  ChecklistAppEntity.swift
//  LastPlace
//
//  App Intents' representation of a checklist, so Siri/Shortcuts can resolve
//  "Travel" or "my Work checklist" to a real `Checklist` and disambiguate
//  when there's more than one match. Deliberately not named `ChecklistEntity`
//  — that's already the SwiftData persistence model — or `Checklist`, the
//  domain entity; this is a third, intents-only representation that just
//  wraps the id/name Siri needs to display and resolve.
//

import AppIntents
import Foundation

struct ChecklistAppEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Checklist"
    static var defaultQuery = ChecklistEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ChecklistEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [ChecklistAppEntity.ID]) async throws -> [ChecklistAppEntity] {
        let container = try IntentDependencies.make()
        let checklists = try await container.checklistRepository.fetchChecklists()
        let identifierSet = Set(identifiers)
        return checklists
            .filter { identifierSet.contains($0.id) }
            .map { ChecklistAppEntity(id: $0.id, name: $0.name) }
    }

    /// Backs the picker Siri/Shortcuts show when a checklist parameter is
    /// left unresolved — e.g. "Add sunglasses to my checklist" with more
    /// than one checklist saved.
    @MainActor
    func suggestedEntities() async throws -> [ChecklistAppEntity] {
        let container = try IntentDependencies.make()
        let checklists = try await container.checklistRepository.fetchChecklists()
        return checklists.map { ChecklistAppEntity(id: $0.id, name: $0.name) }
    }
}

extension ChecklistEntityQuery: EntityStringQuery {
    /// Lets Siri match a spoken checklist name ("travel") against saved
    /// checklists ("Travel") without requiring an exact match.
    @MainActor
    func entities(matching string: String) async throws -> [ChecklistAppEntity] {
        let container = try IntentDependencies.make()
        let checklists = try await container.checklistRepository.fetchChecklists()
        let query = string.lowercased()
        return checklists
            .filter { $0.name.lowercased().contains(query) }
            .map { ChecklistAppEntity(id: $0.id, name: $0.name) }
    }
}
