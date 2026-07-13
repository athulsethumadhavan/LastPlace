//
//  MockImageStorageService.swift
//  LastPlace
//
//  In-memory implementation used by previews and unit tests. Never touches disk.
//

import Foundation

actor MockImageStorageService: ImageStorageService {
    private var store: [String: Data] = [:]

    init(seed: [String: Data] = [:]) {
        self.store = seed
    }

    func saveImageData(_ data: Data, identifier: String) async throws -> String {
        guard !data.isEmpty else { throw ImageStorageError.invalidData }
        let path = "\(identifier)-\(UUID().uuidString)"
        store[path] = data
        return path
    }

    func loadImageData(from path: String) async throws -> Data {
        guard let data = store[path] else { throw ImageStorageError.notFound }
        return data
    }

    func deleteImage(at path: String) async throws {
        store.removeValue(forKey: path)
    }
}
