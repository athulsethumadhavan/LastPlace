//
//  ImageStorageError.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

enum ImageStorageError: LocalizedError, Sendable {
    case invalidData
    case writeFailed(underlying: String)
    case readFailed(underlying: String)
    case deleteFailed(underlying: String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The image data is invalid."
        case .writeFailed(let underlying):
            return "Couldn't save the image: \(underlying)"
        case .readFailed(let underlying):
            return "Couldn't read the image: \(underlying)"
        case .deleteFailed(let underlying):
            return "Couldn't delete the image: \(underlying)"
        case .notFound:
            return "The image file is missing."
        }
    }
}
