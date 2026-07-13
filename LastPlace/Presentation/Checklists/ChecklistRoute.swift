//
//  ChecklistRoute.swift
//  LastPlace
//

import Foundation

enum ChecklistRoute: Hashable {
    case detail(checklistID: UUID)
    case create
    case linkItem(entryID: UUID)
}
