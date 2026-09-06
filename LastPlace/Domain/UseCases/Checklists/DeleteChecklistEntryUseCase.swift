//
//  DeleteChecklistEntryUseCase.swift
//  LastPlace
//

import Foundation

protocol DeleteChecklistEntryUseCase: Sendable {
    func execute(entryID: UUID) async throws
}

struct DefaultDeleteChecklistEntryUseCase: DeleteChecklistEntryUseCase {
    let checklistRepository: ChecklistRepository

    func execute(entryID: UUID) async throws {
        try await checklistRepository.delete(entryID: entryID)
    }
}
