//
//  ObjectDetectionService.swift
//  LastPlace
//
//  Cross-cutting port for image-based object recognition. Takes JPEG bytes,
//  returns domain `DetectedObject` values. Concrete `Vision` and mock
//  implementations live alongside; scan view models depend on this protocol
//  only.
//

import Foundation

protocol ObjectDetectionService: Sendable {
    /// Runs classification against the provided image and returns the detections
    /// whose confidence meets the `minimumConfidence` threshold, sorted from
    /// highest to lowest confidence.
    func detect(in imageData: Data, minimumConfidence: Double) async throws -> [DetectedObject]
}
