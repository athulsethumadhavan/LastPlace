//
//  FetchChecklistsUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchChecklistsUseCase: Sendable {
    func execute() async throws -> [Checklist]
}

struct DefaultFetchChecklistsUseCase: FetchChecklistsUseCase {
    let checklistRepository: ChecklistRepository

    func execute() async throws -> [Checklist] {
        try await checklistRepository.fetchChecklists()
    }
}
