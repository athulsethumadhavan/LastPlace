//
//  ValidationError.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

enum ValidationError: LocalizedError, Equatable, Sendable {
    case emptyName(field: String)
    case nameTooLong(field: String, limit: Int)
    case tooLong(field: String, limit: Int)
    case invalidCategory
    case missingRoom

    var errorDescription: String? {
        switch self {
        case .emptyName(let field):
            return "\(field.capitalized) name can't be empty."
        case .nameTooLong(let field, let limit):
            return "\(field.capitalized) name must be \(limit) characters or fewer."
        case .tooLong(let field, let limit):
            return "\(field.capitalized) must be \(limit) characters or fewer."
        case .invalidCategory:
            return "Please choose a category."
        case .missingRoom:
            return "Please choose a room."
        }
    }
}
