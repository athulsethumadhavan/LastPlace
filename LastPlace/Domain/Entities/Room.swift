//
//  Room.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct Room: Identifiable, Hashable, Sendable {
    let id: UUID
    var homeID: UUID
    var name: String
    var iconName: String
    var coverImagePath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        homeID: UUID,
        name: String,
        iconName: String = Room.defaultIconName,
        coverImagePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.homeID = homeID
        self.name = name
        self.iconName = iconName
        self.coverImagePath = coverImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Room {
    static let nameMaxLength = 40
    static let defaultIconName = "house"

    /// Shared by `CreateRoomView` and `EditRoomView` so the icon grid is
    /// identical whether you're creating a room or renaming one.
    static let iconSuggestions: [String] = [
        "house", "bed.double", "sofa", "fork.knife", "cooktop",
        "bathtub", "shower", "washer", "dryer", "tent", "chair.lounge",
        "books.vertical", "desktopcomputer", "briefcase", "shippingbox",
        "car", "figure.walk", "leaf", "tree"
    ]

    func validated() throws -> Room {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyName(field: "room") }
        guard trimmed.count <= Room.nameMaxLength else {
            throw ValidationError.nameTooLong(field: "room", limit: Room.nameMaxLength)
        }
        var copy = self
        copy.name = trimmed
        return copy
    }
}
