//
//  AIItemIdentificationService.swift
//  LastPlace
//
//  Cloud vision-AI naming, tried before falling back to the on-device
//  `ObjectDetectionService` pipeline. Unlike Vision's fixed ~1000-class
//  classifier, a vision-capable LLM can name a specific item in natural
//  language (e.g. "black leather wallet" rather than the closest of a
//  thousand rigid ImageNet-style labels) and pick a category directly
//  instead of `ScanSaveItemViewModel` guessing one from keywords.
//
//  Deliberately a separate protocol from `ObjectDetectionService` rather
//  than a new case on it: this one is online-only, costs money per call,
//  and returns a single best guess rather than a ranked list of
//  detections — different enough contracts that folding them into one
//  protocol would mean every implementation half-supporting the other's
//  shape.
//

import Foundation

struct AIItemIdentification: Sendable {
    let name: String
    let category: ItemCategory
    let confidence: Double
}

enum AIItemIdentificationError: LocalizedError, Sendable {
    case notAuthenticated
    case serverNotConfigured
    case requestFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to use AI naming."
        case .serverNotConfigured:
            return "AI naming isn't configured yet."
        case .requestFailed(let underlying):
            return underlying
        }
    }
}

protocol AIItemIdentificationService: Sendable {
    /// Identifies the single most prominent item in the photo. Callers
    /// should treat any thrown error (no network, server error, low
    /// confidence) as a cue to fall back to on-device detection rather
    /// than surface it directly — see `ScanCoordinator.runDetection`.
    func identifyItem(in imageData: Data) async throws -> AIItemIdentification
}
