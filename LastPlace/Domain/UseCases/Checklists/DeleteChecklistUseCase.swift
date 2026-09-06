//
//  DeleteChecklistUseCase.swift
//  LastPlace
//

import Foundation

protocol DeleteChecklistUseCase: Sendable {
    func execute(id: UUID) async throws
}

struct DefaultDeleteChecklistUseCase: DeleteChecklistUseCase {
    let checklistRepository: ChecklistRepository

    func execute(id: UUID) async throws {
        try await checklistRepository.delete(checklistID: id)
    }
}
