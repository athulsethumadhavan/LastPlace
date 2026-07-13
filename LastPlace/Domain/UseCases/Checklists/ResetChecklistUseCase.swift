//
//  ResetChecklistUseCase.swift
//  LastPlace
//

import Foundation

protocol ResetChecklistUseCase: Sendable {
    func execute(id: UUID) async throws
}

struct DefaultResetChecklistUseCase: ResetChecklistUseCase {
    let checklistRepository: ChecklistRepository

    func execute(id: UUID) async throws {
        try await checklistRepository.resetChecklist(id: id)
    }
}
