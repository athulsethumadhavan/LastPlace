//
//  ScanSessionEntity.swift
//  LastPlace
//
//  No `@Attribute(.unique)` — CloudKit-backed SwiftData doesn't support
//  unique constraints, so uniqueness on `id` is enforced at the repository
//  layer (fetch-before-insert) instead. Every non-optional property has a
//  default value, which CloudKit's schema requires.
//

import Foundation
import SwiftData

@Model
final class ScanSessionEntity {
    var id: UUID = UUID()
    var roomID: UUID = UUID()
    var startedAt: Date = Date()
    var completedAt: Date?
    var capturedImagePaths: [String] = []
    var statusRaw: String = ""

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
