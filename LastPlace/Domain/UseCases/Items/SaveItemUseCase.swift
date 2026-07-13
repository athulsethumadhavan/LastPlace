//
//  SaveItemUseCase.swift
//  LastPlace
//
//  Persists the image, creates the item, and records the initial snapshot so
//  the view model doesn't have to orchestrate three services.
//

import Foundation

struct SaveItemInput: Sendable {
    let roomID: UUID
    let name: String
    let category: ItemCategory
    let notes: String?
    let locationDescription: String
    let imageData: Data?
    let isImportant: Bool
    let source: SnapshotSource
    let capturedAt: Date

    init(
        roomID: UUID,
        name: String,
        category: ItemCategory,
        notes: String? = nil,
        locationDescription: String,
        imageData: Data? = nil,
        isImportant: Bool = false,
        source: SnapshotSource = .manual,
        capturedAt: Date = Date()
    ) {
        self.roomID = roomID
        self.name = name
        self.category = category
        self.notes = notes
        self.locationDescription = locationDescription
        self.imageData = imageData
        self.isImportant = isImportant
        self.source = source
        self.capturedAt = capturedAt
    }
}

protocol SaveItemUseCase: Sendable {
    func execute(_ input: SaveItemInput) async throws -> StoredItem
}

struct DefaultSaveItemUseCase: SaveItemUseCase {
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let imageStorage: ImageStorageService

    func execute(_ input: SaveItemInput) async throws -> StoredItem {
        let itemID = UUID()

        var imagePath: String?
        if let data = input.imageData {
            imagePath = try await imageStorage.saveImageData(data, identifier: "item-\(itemID.uuidString)")
        }

        let draft = StoredItem(
            id: itemID,
            roomID: input.roomID,
            name: input.name,
            category: input.category,
            notes: input.notes,
            imagePath: imagePath,
            locationDescription: input.locationDescription,
            lastSeenAt: input.capturedAt,
            isImportant: input.isImportant
        )
        let validated = try draft.validated()
        let saved = try await itemRepository.create(validated)

        let snapshot = ItemSnapshot(
            itemID: saved.id,
            roomID: saved.roomID,
            imagePath: imagePath,
            locationDescription: saved.locationDescription,
            capturedAt: input.capturedAt,
            confidence: 0,
            source: input.source
        )
        _ = try await snapshotRepository.create(snapshot)

        return saved
    }
}
