//
//  FileImageStorageService.swift
//  LastPlace
//
//  Stores images in the app's Application Support directory under a stable
//  subfolder. Returns paths *relative* to that root so SwiftData never holds
//  an absolute URL that could break across reinstalls / iCloud restores.
//

import Foundation

actor FileImageStorageService: ImageStorageService {
    private let rootDirectory: URL
    private let fileManager: FileManager

    init(
        fileManager: FileManager = .default,
        subdirectory: String = "Images"
    ) throws {
        self.fileManager = fileManager
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent(subdirectory, isDirectory: true)
        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        self.rootDirectory = root
    }

    func saveImageData(_ data: Data, identifier: String) async throws -> String {
        guard !data.isEmpty else { throw ImageStorageError.invalidData }

        let filename = "\(sanitized(identifier))-\(UUID().uuidString).jpg"
        let target = rootDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw ImageStorageError.writeFailed(underlying: error.localizedDescription)
        }
        return filename
    }

    func loadImageData(from path: String) async throws -> Data {
        let url = rootDirectory.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ImageStorageError.notFound
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ImageStorageError.readFailed(underlying: error.localizedDescription)
        }
    }

    func deleteImage(at path: String) async throws {
        let url = rootDirectory.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ImageStorageError.deleteFailed(underlying: error.localizedDescription)
        }
    }

    private nonisolated func sanitized(_ identifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = identifier.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars)
        return cleaned.isEmpty ? "image" : cleaned
    }
}
