//
//  ImageStorageService.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//
//  Cross-cutting infrastructure port. Only Foundation types are used so this
//  protocol stays free of UI / persistence dependencies. Concrete file-system
//  and mock implementations live alongside in Phase 2.
//

import Foundation

protocol ImageStorageService: Sendable {
    /// Persists `data` under a stable identifier and returns a path relative to
    /// the app's storage root — safe to persist in SwiftData.
    func saveImageData(_ data: Data, identifier: String) async throws -> String

    /// Loads image bytes for a previously saved relative path.
    func loadImageData(from path: String) async throws -> Data

    /// Deletes the image file at the given relative path. Missing files are
    /// treated as a no-op.
    func deleteImage(at path: String) async throws
}
