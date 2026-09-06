//
//  ChecklistRoute.swift
//  LastPlace
//

import Foundation

enum ChecklistRoute: Hashable {
    case detail(checklistID: UUID)
    case create
    /// Add-item screen for an existing checklist — lets the user type a
    /// free-text entry or pick a saved `StoredItem` to link (see
    /// `AddChecklistEntryInput.linkedItemID`).
    case linkItem(checklistID: UUID)
}
