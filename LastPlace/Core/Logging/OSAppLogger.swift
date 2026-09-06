//
//  OSAppLogger.swift
//  LastPlace
//

import Foundation
import os

struct OSAppLogger: AppLogger {
    private static let subsystem = "com.lastplace.app"

    func log(_ message: String, category: String) {
        Logger(subsystem: Self.subsystem, category: category).log("\(message, privacy: .public)")
    }

    func warning(_ message: String, category: String) {
        Logger(subsystem: Self.subsystem, category: category).warning("\(message, privacy: .public)")
    }

    func error(_ message: String, error: Error?, category: String) {
        let logger = Logger(subsystem: Self.subsystem, category: category)
        if let error {
            logger.error("\(message, privacy: .public) — \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }
}
