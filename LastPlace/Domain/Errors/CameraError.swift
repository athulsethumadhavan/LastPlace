//
//  CameraError.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

enum CameraError: LocalizedError, Sendable {
    case notAuthorized
    case unavailable
    case captureFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access is disabled. Enable it in Settings to capture photos."
        case .unavailable:
            return "The camera isn't available on this device."
        case .captureFailed(let underlying):
            return "Photo capture failed: \(underlying)"
        }
    }
}
