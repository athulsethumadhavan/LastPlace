//
//  DetectedObject.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//
//  Domain-level output of the VisionRecognitionService port.
//  CoreGraphics is UI-free and safe in the domain layer.
//

import Foundation
import CoreGraphics

struct DetectedObject: Identifiable, Hashable, Sendable {
    let id: UUID
    var label: String
    var confidence: Double
    var boundingBox: CGRect
    /// Set only when the label came from `AIItemIdentificationService`,
    /// which names a category directly instead of leaving
    /// `ScanSaveItemViewModel` to guess one via keyword-matching the label
    /// (still the fallback for on-device Vision detections, where this is
    /// nil).
    var suggestedCategory: ItemCategory?

    init(
        id: UUID = UUID(),
        label: String,
        confidence: Double,
        boundingBox: CGRect,
        suggestedCategory: ItemCategory? = nil
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.suggestedCategory = suggestedCategory
    }
}
