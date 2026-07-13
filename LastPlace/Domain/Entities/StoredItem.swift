//
//  StoredItem.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct StoredItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var roomID: UUID
    var name: String
    var category: ItemCategory
    var notes: String?
    var imagePath: String?
    var locationDescription: String
    var lastSeenAt: Date
    var createdAt: Date
    var updatedAt: Date
    var isImportant: Bool

    init(
        id: UUID = UUID(),
        roomID: UUID,
        name: String,
        category: ItemCategory,
        notes: String? = nil,
        imagePath: String? = nil,
        locationDescription: String,
        lastSeenAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isImportant: Bool = false
    ) {
        self.id = id
        self.roomID = roomID
        self.name = name
        self.category = category
        self.notes = notes
        self.imagePath = imagePath
        self.locationDescription = locationDescription
        self.lastSeenAt = lastSeenAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isImportant = isImportant
    }
}

extension StoredItem {
    static let nameMaxLength = 60
    static let notesMaxLength = 500
    static let locationMaxLength = 140

    func validated() throws -> StoredItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ValidationError.emptyName(field: "item") }
        guard trimmedName.count <= StoredItem.nameMaxLength else {
            throw ValidationError.nameTooLong(field: "item", limit: StoredItem.nameMaxLength)
        }

        let trimmedLocation = locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLocation.count <= StoredItem.locationMaxLength else {
            throw ValidationError.tooLong(field: "location", limit: StoredItem.locationMaxLength)
        }

        if let notesValue = notes, notesValue.count > StoredItem.notesMaxLength {
            throw ValidationError.tooLong(field: "notes", limit: StoredItem.notesMaxLength)
        }

        var copy = self
        copy.name = trimmedName
        copy.locationDescription = trimmedLocation
        return copy
    }
}
