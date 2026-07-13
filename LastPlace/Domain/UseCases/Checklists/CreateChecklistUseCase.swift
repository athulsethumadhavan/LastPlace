//
//  CreateChecklistUseCase.swift
//  LastPlace
//

import Foundation

protocol CreateChecklistUseCase: Sendable {
    func execute(name: String, type: ChecklistType) async throws -> Checklist
}

struct DefaultCreateChecklistUseCase: CreateChecklistUseCase {
    let checklistRepository: ChecklistRepository

    func execute(name: String, type: ChecklistType) async throws -> Checklist {
        let draft = Checklist(name: name, type: type)
        let validated = try draft.validated()
        return try await checklistRepository.create(validated)
    }
}
