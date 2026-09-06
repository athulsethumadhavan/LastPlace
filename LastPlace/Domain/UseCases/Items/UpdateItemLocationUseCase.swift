//
//  UpdateItemLocationUseCase.swift
//  LastPlace
//

import Foundation

struct UpdateItemLocationInput: Sendable {
    let itemID: UUID
    let description: String
    let imageData: Data?
    let source: SnapshotSource
    let capturedAt: Date

    init(
        itemID: UUID,
        description: String,
        imageData: Data? = nil,
        source: SnapshotSource = .manual,
        capturedAt: Date = Date()
    ) {
        self.itemID = itemID
        self.description = description
        self.imageData = imageData
        self.source = source
        self.capturedAt = capturedAt
    }
}

protocol UpdateItemLocationUseCase: Sendable {
    func execute(_ input: UpdateItemLocationInput) async throws -> StoredItem
}

struct DefaultUpdateItemLocationUseCase: UpdateItemLocationUseCase {
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let imageStorage: ImageStorageService

    func execute(_ input: UpdateItemLocationInput) async throws -> StoredItem {
        var imagePath: String?
        if let data = input.imageData {
            imagePath = try await imageStorage.saveImageData(
                data,
                identifier: "snapshot-\(input.itemID.uuidString)-\(UUID().uuidString)"
            )
        }

        let trimmed = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= StoredItem.locationMaxLength else {
            throw ValidationError.tooLong(field: "location", limit: StoredItem.locationMaxLength)
        }

        let updated = try await itemRepository.updateLocation(
            itemID: input.itemID,
            description: trimmed,
            imagePath: imagePath,
            at: input.capturedAt
        )

        let snapshot = ItemSnapshot(
            itemID: updated.id,
            roomID: updated.roomID,
            imagePath: imagePath,
            locationDescription: updated.locationDescription,
            capturedAt: input.capturedAt,
            confidence: 0,
            source: input.source
        )
        _ = try await snapshotRepository.create(snapshot)

        return updated
    }
}
