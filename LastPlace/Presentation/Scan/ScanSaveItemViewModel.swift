//
//  ScanSaveItemViewModel.swift
//  LastPlace
//
//  Backs the save-item form launched from a scan detection. Pre-fills the
//  name and category from the detection label, keeps the captured photo bytes,
//  and delegates persistence to `SaveItemUseCase`.
//

import Foundation
import Observation

@Observable
@MainActor
final class ScanSaveItemViewModel {
    var name: String
    var category: ItemCategory
    var locationDescription: String = ""
    var notes: String = ""
    var isImportant: Bool = false
    var isSaving: Bool = false
    var error: UserFacingError?

    let imageData: Data?
    let detectionLabel: String
    let confidence: Double

    private let roomID: UUID
    private let capturedAt: Date
    private let saveItemUseCase: SaveItemUseCase
    private let logger: AppLogger

    init(
        roomID: UUID,
        capturedAt: Date,
        imageData: Data?,
        detection: DetectedObject,
        confidence: Double,
        saveItem: SaveItemUseCase,
        logger: AppLogger
    ) {
        self.roomID = roomID
        self.capturedAt = capturedAt
        self.imageData = imageData
        self.detectionLabel = detection.label
        self.confidence = confidence
        self.saveItemUseCase = saveItem
        self.logger = logger

        self.name = detection.label
        self.category = ScanSaveItemViewModel.suggestCategory(for: detection.label)
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    /// Returns the persisted item so the caller can dismiss on success.
    func save() async -> StoredItem? {
        guard canSave else { return nil }
        isSaving = true
        error = nil
        defer { isSaving = false }

        let input = SaveItemInput(
            roomID: roomID,
            name: name,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            locationDescription: locationDescription,
            imageData: imageData,
            isImportant: isImportant,
            source: .visionDetection,
            capturedAt: capturedAt
        )

        do {
            return try await saveItemUseCase.execute(input)
        } catch {
            logger.error("Scan save item failed", error: error, category: "scan")
            self.error = UserFacingError.from(error)
            return nil
        }
    }

    /// Best-effort category guess from a Vision label. Coarse — Vision labels
    /// are not category-aligned — but sensible defaults reduce form friction.
    private static func suggestCategory(for label: String) -> ItemCategory {
        let lower = label.lowercased()
        switch true {
        case lower.contains("laptop"), lower.contains("computer"), lower.contains("phone"),
             lower.contains("tablet"), lower.contains("television"), lower.contains("monitor"),
             lower.contains("camera"), lower.contains("headphone"), lower.contains("speaker"):
            return .electronics
        case lower.contains("key"):
            return .keys
        case lower.contains("wallet"), lower.contains("purse"):
            return .wallets
        case lower.contains("glass"), lower.contains("spectacle"), lower.contains("sunglass"):
            return .glasses
        case lower.contains("bag"), lower.contains("backpack"), lower.contains("handbag"),
             lower.contains("luggage"):
            return .bags
        case lower.contains("shirt"), lower.contains("jacket"), lower.contains("dress"),
             lower.contains("shoe"), lower.contains("hat"), lower.contains("coat"):
            return .clothing
        case lower.contains("charger"), lower.contains("cable"), lower.contains("adapter"),
             lower.contains("battery"):
            return .chargers
        case lower.contains("hammer"), lower.contains("wrench"), lower.contains("drill"),
             lower.contains("tool"):
            return .tools
        case lower.contains("pill"), lower.contains("medicine"), lower.contains("bottle"):
            return .medication
        case lower.contains("ring"), lower.contains("necklace"), lower.contains("bracelet"),
             lower.contains("jewel"):
            return .jewelry
        case lower.contains("document"), lower.contains("paper"), lower.contains("passport"),
             lower.contains("book"):
            return .documents
        default:
            return .other
        }
    }
}
