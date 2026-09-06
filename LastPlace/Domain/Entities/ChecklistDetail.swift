//
//  ChecklistDetail.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct ChecklistDetail: Hashable, Sendable {
    let checklist: Checklist
    let entries: [ChecklistEntry]

    var completedCount: Int { entries.filter(\.isCompleted).count }
    var totalCount: Int { entries.count }
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}
