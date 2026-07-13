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

    init(
        id: UUID = UUID(),
        label: String,
        confidence: Double,
        boundingBox: CGRect
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
