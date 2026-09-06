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
    /// Set instead of `error` when the save was refused by the free-tier
    /// cap. Kept separate so the view presents the paywall rather than an
    /// alert -- "you've run out of free items" is an offer, and rendering it
    /// as an error with an OK button gives someone nothing to act on.
    var paywallReason: PaywallReason?

    let imageData: Data?
    let detectionLabel: String
    let confidence: Double

    private let roomID: UUID
    private let capturedAt: Date
    private let saveItemUseCase: SaveItemUseCase
    private let analytics: AnalyticsService
    private let logger: AppLogger
    /// Which naming path produced the pre-filled name, captured at init so
    /// `save()` can report it -- see the `.itemNamed` event there.
    private let namingOutcome: AnalyticsEvent.NamingOutcome

    init(
        roomID: UUID,
        capturedAt: Date,
        imageData: Data?,
        detection: DetectedObject,
        confidence: Double,
        saveItem: SaveItemUseCase,
        analytics: AnalyticsService,
        logger: AppLogger
    ) {
        self.roomID = roomID
        self.capturedAt = capturedAt
        self.imageData = imageData
        self.detectionLabel = detection.label
        self.confidence = confidence
        self.saveItemUseCase = saveItem
        self.analytics = analytics
        self.logger = logger
        // `suggestedCategory` is set only by `AIItemIdentificationService`
        // (see `DetectedObject`), so it doubles as the marker for which
        // naming path produced this detection.
        self.namingOutcome = detection.suggestedCategory != nil ? .ai : .visionFallback

        self.name = detection.label
        // AI-identified detections already name a category directly; only
        // fall back to keyword-guessing for on-device Vision detections.
        self.category = detection.suggestedCategory ?? ScanSaveItemViewModel.suggestCategory(for: detection.label)
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
            let saved = try await saveItemUseCase.execute(input)
            analytics.log(.itemSaved(
                source: .scan,
                category: category,
                hasPhoto: imageData != nil
            ))
            // Logged on save rather than on detection so it reflects names
            // the person actually kept -- a suggestion they rejected and
            // retyped shouldn't count as the AI having named the item.
            // `.none` covers exactly that case: the suggested label was
            // edited away before saving.
            let keptSuggestion = name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(detectionLabel.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            analytics.log(.itemNamed(outcome: keptSuggestion ? namingOutcome : .none))
            return saved
        } catch let limit as ItemLimitReachedError {
            // Not logged as an error -- hitting the free cap is expected
            // product behaviour, and logging it as a failure makes real
            // save failures harder to find later.
            logger.log("Save blocked by free-tier item limit (\(limit.limit))", category: "scan")
            paywallReason = .itemLimitReached
            return nil
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
