//
//  AddChecklistEntryUseCase.swift
//  LastPlace
//

import Foundation

struct AddChecklistEntryInput: Sendable {
    let checklistID: UUID
    let title: String
    let linkedItemID: UUID?
    let sortOrder: Int

    init(checklistID: UUID, title: String, linkedItemID: UUID? = nil, sortOrder: Int = 0) {
        self.checklistID = checklistID
        self.title = title
        self.linkedItemID = linkedItemID
        self.sortOrder = sortOrder
    }
}

protocol AddChecklistEntryUseCase: Sendable {
    func execute(_ input: AddChecklistEntryInput) async throws -> ChecklistEntry
}

struct DefaultAddChecklistEntryUseCase: AddChecklistEntryUseCase {
    let checklistRepository: ChecklistRepository

    func execute(_ input: AddChecklistEntryInput) async throws -> ChecklistEntry {
        let draft = ChecklistEntry(
            checklistID: input.checklistID,
            title: input.title,
            linkedItemID: input.linkedItemID,
            isCompleted: false,
            sortOrder: input.sortOrder
        )
        let validated = try draft.validated()
        return try await checklistRepository.addEntry(validated)
    }
}
