//
//  ItemSnapshot.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct ItemSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    var itemID: UUID
    var roomID: UUID
    var imagePath: String?
    var locationDescription: String
    var capturedAt: Date
    var confidence: Double
    var source: SnapshotSource

    init(
        id: UUID = UUID(),
        itemID: UUID,
        roomID: UUID,
        imagePath: String? = nil,
        locationDescription: String,
        capturedAt: Date = Date(),
        confidence: Double = 0,
        source: SnapshotSource
    ) {
        self.id = id
        self.itemID = itemID
        self.roomID = roomID
        self.imagePath = imagePath
        self.locationDescription = locationDescription
        self.capturedAt = capturedAt
        self.confidence = confidence
        self.source = source
    }
}

enum SnapshotSource: String, Codable, Hashable, Sendable, CaseIterable {
    case manual
    case scan
    case importedPhoto
    case visionDetection
}
