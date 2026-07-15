//
//  ChecklistEntryEntity.swift
//  LastPlace
//
//  `locationDescription` was added after the initial schema — it's Optional
//  so SwiftData's lightweight migration can add the column without a
//  migration plan. Only meaningful for unlinked entries; see the domain
//  entity's doc comment.
//

import Foundation
import SwiftData

@Model
final class ChecklistEntryEntity {
    @Attribute(.unique) var id: UUID
    var checklistID: UUID
    var title: String
    var linkedItemID: UUID?
    var locationDescription: String?
    var isCompleted: Bool
    var sortOrder: Int

    init(
        id: UUID,
        checklistID: UUID,
        title: String,
        linkedItemID: UUID?,
        locationDescription: String? = nil,
        isCompleted: Bool,
        sortOrder: Int
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
