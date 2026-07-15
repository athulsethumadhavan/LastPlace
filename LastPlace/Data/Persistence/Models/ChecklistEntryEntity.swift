//
//  ChecklistEntryEntity.swift
//  LastPlace
//
//  `locationDescription` was added after the initial schema — it's Optional
//  so SwiftData's lightweight migration can add the column without a
//  migration plan. Only meaningful for unlinked entries; see the domain
//  entity's doc comment.
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
//

import Foundation
import SwiftData

@Model
final class ChecklistEntryEntity {
    var id: UUID = UUID()
    var checklistID: UUID = UUID()
    var title: String = ""
    var linkedItemID: UUID?
    var locationDescription: String?
    var isCompleted: Bool = false
    var sortOrder: Int = 0

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
