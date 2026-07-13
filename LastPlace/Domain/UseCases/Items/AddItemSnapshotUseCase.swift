//
//  AddItemSnapshotUseCase.swift
//  LastPlace
//

import Foundation

struct AddItemSnapshotInput: Sendable {
    let itemID: UUID
    let imageData: Data?
    let locationDescription: String
    let source: SnapshotSource
    let capturedAt: Date

    init(
        itemID: UUID,
        imageData: Data? = nil,
        locationDescription: String,
        source: SnapshotSource = .manual,
        capturedAt: Date = Date()
    ) {
        self.itemID = itemID
        self.imageData = imageData
        self.locationDescription = locationDescription
        self.source = source
        self.capturedAt = capturedAt
    }
}

protocol AddItemSnapshotUseCase: Sendable {
    func execute(_ input: AddItemSnapshotInput) async throws -> ItemSnapshot
}

struct DefaultAddItemSnapshotUseCase: AddItemSnapshotUseCase {
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let imageStorage: ImageStorageService

    func execute(_ input: AddItemSnapshotInput) async throws -> ItemSnapshot {
        let item = try await itemRepository.fetchItem(itemID: input.itemID)

        var imagePath: String?
        if let data = input.imageData {
            imagePath = try await imageStorage.saveImageData(
                data,
                identifier: "snapshot-\(item.id.uuidString)-\(UUID().uuidString)"
            )
        }

        let snapshot = ItemSnapshot(
            itemID: item.id,
            roomID: item.roomID,
            imagePath: imagePath,
            locationDescription: input.locationDescription,
            capturedAt: input.capturedAt,
            confidence: 0,
            source: input.source
        )
        return try await snapshotRepository.create(snapshot)
    }
}
