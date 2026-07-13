//
//  ChecklistEntry.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct ChecklistEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var checklistID: UUID
    var title: String
    var linkedItemID: UUID?
    var isCompleted: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        checklistID: UUID,
        title: String,
        linkedItemID: UUID? = nil,
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.checklistID = checklistID
        self.title = title
        self.linkedItemID = linkedItemID
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}

extension ChecklistEntry {
    static let titleMaxLength = 80

    func validated() throws -> ChecklistEntry {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyName(field: "checklist entry") }
        guard trimmed.count <= ChecklistEntry.titleMaxLength else {
            throw ValidationError.nameTooLong(field: "checklist entry", limit: ChecklistEntry.titleMaxLength)
        }
        var copy = self
        copy.title = trimmed
        return copy
    }
}
