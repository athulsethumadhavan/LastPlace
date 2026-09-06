//
//  FetchChecklistDetailUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchChecklistDetailUseCase: Sendable {
    func execute(id: UUID) async throws -> ChecklistDetail
}

struct DefaultFetchChecklistDetailUseCase: FetchChecklistDetailUseCase {
    let checklistRepository: ChecklistRepository

    func execute(id: UUID) async throws -> ChecklistDetail {
        let checklist = try await checklistRepository.fetchChecklist(id: id)
        let entries = try await checklistRepository.fetchEntries(checklistID: id)
        return ChecklistDetail(checklist: checklist, entries: entries)
    }
}
