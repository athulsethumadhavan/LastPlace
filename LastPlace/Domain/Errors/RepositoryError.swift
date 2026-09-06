//
//  RepositoryError.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

enum RepositoryError: LocalizedError, Sendable {
    case notFound
    case duplicate
    case persistenceFailed(underlying: String)
    case invalidState(reason: String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The requested item couldn't be found."
        case .duplicate:
            return "That already exists."
        case .persistenceFailed(let underlying):
            return "Couldn't save your changes: \(underlying)"
        case .invalidState(let reason):
            return reason
        }
    }
}
