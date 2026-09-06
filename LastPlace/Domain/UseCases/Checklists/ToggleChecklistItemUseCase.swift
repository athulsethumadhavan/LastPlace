//
//  ToggleChecklistItemUseCase.swift
//  LastPlace
//

import Foundation

protocol ToggleChecklistItemUseCase: Sendable {
    func execute(entryID: UUID) async throws -> ChecklistEntry
}

struct DefaultToggleChecklistItemUseCase: ToggleChecklistItemUseCase {
    let checklistRepository: ChecklistRepository

    func execute(entryID: UUID) async throws -> ChecklistEntry {
        try await checklistRepository.toggle(entryID: entryID)
    }
}
