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

/// Thrown when a free account tries to save past the item cap.
///
/// Its own type rather than a `ValidationError`, because the caller needs to
/// tell it apart from "that name is too long" — one is corrected by editing
/// the form, the other by subscribing, and they need different UI.
struct ItemLimitReachedError: LocalizedError, Sendable, Equatable {
    let limit: Int

    var errorDescription: String? {
        "Free accounts can save up to \(limit) items."
    }
}

protocol SaveItemUseCase: Sendable {
    func execute(_ input: SaveItemInput) async throws -> StoredItem
}

struct DefaultSaveItemUseCase: SaveItemUseCase {
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let imageStorage: ImageStorageService
    let entitlementService: EntitlementService

    func execute(_ input: SaveItemInput) async throws -> StoredItem {
        // The cap is checked here rather than in the view model so every
        // creation path inherits it -- there is currently one (the scan save
        // form, which "Add Manually" also routes through), but a second one
        // added later shouldn't have to remember.
        //
        // Counts local rows against the *remote* entitlement. Saving is
        // local-first, so the server's insert trigger doesn't fire until the
        // next sync; without this check a free user would create items that
        // look saved and then silently fail to push.
        //
        // A failed entitlement lookup degrades to free rather than throwing:
        // being offline shouldn't block someone under the limit from saving,
        // and someone over it is still caught by the server on sync.
        let status = await entitlementService.statusOrFree()
        if !status.isPremium {
            let count = try await itemRepository.countItems()
            guard count < EntitlementStatus.freeItemLimit else {
                throw ItemLimitReachedError(limit: EntitlementStatus.freeItemLimit)
            }
        }

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
