//
//  AppLogger.swift
//  LastPlace
//

import Foundation

protocol AppLogger: Sendable {
    func log(_ message: String, category: String)
    func warning(_ message: String, category: String)
    func error(_ message: String, error: Error?, category: String)
}

extension AppLogger {
    func log(_ message: String) { log(message, category: "app") }
    func warning(_ message: String) { warning(message, category: "app") }
    func error(_ message: String, error: Error? = nil) {
        self.error(message, error: error, category: "app")
    }
}
