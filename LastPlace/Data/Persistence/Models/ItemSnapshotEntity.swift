//
//  ItemSnapshotEntity.swift
//  LastPlace
//

import Foundation
import SwiftData

@Model
final class ItemSnapshotEntity {
    @Attribute(.unique) var id: UUID
    var itemID: UUID
    var roomID: UUID
    var imagePath: String?
    var locationDescription: String
    var capturedAt: Date
    var confidence: Double
    var sourceRaw: String

    init(
        id: UUID,
        itemID: UUID,
        roomID: UUID,
        imagePath: String?,
        locationDescription: String,
        capturedAt: Date,
        confidence: Double,
        sourceRaw: String
    ) {
        self.id = id
        self.itemID = itemID
        self.roomID = roomID
        self.imagePath = imagePath
        self.locationDescription = locationDescription
        self.capturedAt = capturedAt
        self.confidence = confidence
        self.sourceRaw = sourceRaw
    }
}
