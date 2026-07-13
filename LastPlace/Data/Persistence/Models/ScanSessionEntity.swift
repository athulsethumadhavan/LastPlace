//
//  ScanSessionEntity.swift
//  LastPlace
//

import Foundation
import SwiftData

@Model
final class ScanSessionEntity {
    @Attribute(.unique) var id: UUID
    var roomID: UUID
    var startedAt: Date
    var completedAt: Date?
    var capturedImagePaths: [String]
    var statusRaw: String

    init(
        id: UUID,
        roomID: UUID,
        startedAt: Date,
        completedAt: Date?,
        capturedImagePaths: [String],
        statusRaw: String
    ) {
        self.id = id
        self.roomID = roomID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.capturedImagePaths = capturedImagePaths
        self.statusRaw = statusRaw
    }
}
