//
//  RemoteImageCache.swift
//  LastPlace
//
//  Simple disk cache for `AsyncRemoteImage` (Phase 4 shared-room content).
//  Deliberately separate from `FileImageStorageService`'s Application
//  Support directory: that one holds this device's *own* images, tracked
//  by `SyncEngine.collectReferencedImagePaths()` against local SwiftData
//  entities, and shared content is never referenced by a local entity. It
//  also deliberately lives in `.cachesDirectory`, not Application Support
//  — the OS is free to purge it under storage pressure, which is exactly
//  the "no manual eviction" tradeoff: if a share gets revoked, the stale
//  cached photo just sits there like any other cache entry until iOS
//  reclaims the space, rather than the app tracking and cleaning it up
//  itself.
//

import Foundation

actor RemoteImageCache {
    static let shared = RemoteImageCache()

    private let rootDirectory: URL?

    private init() {
        let base = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        guard let base else {
            rootDirectory = nil
            return
        }
        let root = base.appendingPathComponent("SharedImageCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        rootDirectory = root
    }

    func data(forKey key: String) -> Data? {
        guard let url = fileURL(forKey: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    func store(_ data: Data, forKey key: String) {
        guard let url = fileURL(forKey: key) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func fileURL(forKey key: String) -> URL? {
        guard let rootDirectory else { return nil }
        return rootDirectory.appendingPathComponent(sanitized(key))
    }

    private nonisolated func sanitized(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = key.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars)
        return cleaned.isEmpty ? "image" : cleaned
    }
}
