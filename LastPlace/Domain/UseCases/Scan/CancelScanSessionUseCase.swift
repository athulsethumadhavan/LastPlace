//
//  CancelScanSessionUseCase.swift
//  LastPlace
//
//  Cancels the session and best-effort removes any images captured during it,
//  so an abandoned scan doesn't leave orphaned files in the documents dir.
//

import Foundation

protocol CancelScanSessionUseCase: Sendable {
    func execute(sessionID: UUID) async throws
}

struct DefaultCancelScanSessionUseCase: CancelScanSessionUseCase {
    let scanRepository: ScanRepository
    let imageStorage: ImageStorageService

    func execute(sessionID: UUID) async throws {
        let session = try await scanRepository.fetchSession(id: sessionID)
        for path in session.capturedImagePaths {
            try? await imageStorage.deleteImage(at: path)
        }
        try await scanRepository.cancel(sessionID: sessionID)
    }
}
