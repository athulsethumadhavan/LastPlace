//
//  UserFacingError.swift
//  LastPlace
//
//  A view-model-safe error type: title + message + retry hint. All domain /
//  infrastructure errors are translated through `UserFacingError.from(_:)` so
//  raw `NSError` descriptions never bleed into the UI.
//

import Foundation

struct UserFacingError: LocalizedError, Sendable, Hashable {
    let title: String
    let message: String
    let isRetryable: Bool

    init(
        title: String = "Something went wrong",
        message: String,
        isRetryable: Bool = true
    ) {
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }

    var errorDescription: String? { message }

    static func from(_ error: Error) -> UserFacingError {
        if let userFacing = error as? UserFacingError { return userFacing }

        if let validation = error as? ValidationError {
            return UserFacingError(
                title: "Please fix that",
                message: validation.errorDescription ?? "Please review your input.",
                isRetryable: false
            )
        }

        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return UserFacingError(message: message)
        }

        return UserFacingError(message: error.localizedDescription)
    }
}
