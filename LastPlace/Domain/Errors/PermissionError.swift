//
//  PermissionError.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

enum PermissionError: LocalizedError, Sendable {
    case cameraDenied
    case photoLibraryDenied
    case restricted

    var errorDescription: String? {
        switch self {
        case .cameraDenied:
            return "Camera access is required. Enable it in Settings."
        case .photoLibraryDenied:
            return "Photo library access is required. Enable it in Settings."
        case .restricted:
            return "This device has restrictions that prevent this action."
        }
    }
}
