//
//  ChecklistEntryEntity.swift
//  LastPlace
//

import Foundation
import SwiftData

@Model
final class ChecklistEntryEntity {
    @Attribute(.unique) var id: UUID
    var checklistID: UUID
    var title: String
    var linkedItemID: UUID?
    var isCompleted: Bool
    var sortOrder: Int

    init(
        id: UUID,
        checklistID: UUID,
        title: String,
        linkedItemID: UUID?,
        isCompleted: Bool,
        sortOrder: Int
    ) {
        self.id = id
        self.checklistID = checklistID
        self.title = title
        self.linkedItemID = linkedItemID
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}
