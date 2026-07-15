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
    /// Free-text location, only meaningful when `linkedItemID` is `nil`. A
    /// linked entry always shows the live location of its `StoredItem`
    /// instead (see `ChecklistDetailViewModel.linkedItems`), so this stays
    /// unused in that case rather than drifting out of sync with it.
    var locationDescription: String?
    var isCompleted: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        checklistID: UUID,
        title: String,
        linkedItemID: UUID? = nil,
        locationDescription: String? = nil,
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.checklistID = checklistID
        self.title = title
        self.linkedItemID = linkedItemID
        self.locationDescription = locationDescription
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}

extension ChecklistEntry {
    static let titleMaxLength = 80
    static let locationMaxLength = 140

    func validated() throws -> ChecklistEntry {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyName(field: "checklist entry") }
        guard trimmed.count <= ChecklistEntry.titleMaxLength else {
            throw ValidationError.nameTooLong(field: "checklist entry", limit: ChecklistEntry.titleMaxLength)
        }

        var copy = self
        copy.title = trimmed

        if let location = locationDescription {
            let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLocation.count <= ChecklistEntry.locationMaxLength else {
                throw ValidationError.tooLong(field: "location", limit: ChecklistEntry.locationMaxLength)
            }
            copy.locationDescription = trimmedLocation.isEmpty ? nil : trimmedLocation
        }

        return copy
    }
}
