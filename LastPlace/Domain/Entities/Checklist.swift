//
//  Checklist.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct Checklist: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var type: ChecklistType
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: ChecklistType,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Checklist {
    static let nameMaxLength = 40

    func validated() throws -> Checklist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyName(field: "checklist") }
        guard trimmed.count <= Checklist.nameMaxLength else {
            throw ValidationError.nameTooLong(field: "checklist", limit: Checklist.nameMaxLength)
        }
        var copy = self
        copy.name = trimmed
        return copy
    }
}

enum ChecklistType: Codable, Hashable, Sendable {
    case work
    case travel
    case gym
    case school
    case custom(String)

    var displayName: String {
        switch self {
        case .work:              return "Work"
        case .travel:            return "Travel"
        case .gym:               return "Gym"
        case .school:            return "School"
        case .custom(let label): return label
        }
    }

    var symbolName: String {
        switch self {
        case .work:   return "briefcase"
        case .travel: return "airplane"
        case .gym:    return "dumbbell"
        case .school: return "backpack"
        case .custom: return "list.bullet.rectangle"
        }
    }
}
