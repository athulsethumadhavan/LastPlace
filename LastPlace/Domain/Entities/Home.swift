//
//  Home.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//
//  Domain entity — pure value type. No SwiftData / UI imports.
//

import Foundation

struct Home: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Home {
    static let nameMaxLength = 60

    func validated() throws -> Home {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyName(field: "home") }
        guard trimmed.count <= Home.nameMaxLength else {
            throw ValidationError.nameTooLong(field: "home", limit: Home.nameMaxLength)
        }
        var copy = self
        copy.name = trimmed
        return copy
    }
}
