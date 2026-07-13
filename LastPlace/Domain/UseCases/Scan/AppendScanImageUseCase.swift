//
//  AppendScanImageUseCase.swift
//  LastPlace
//

import Foundation

protocol AppendScanImageUseCase: Sendable {
    func execute(sessionID: UUID, imageData: Data) async throws -> ScanSession
}

struct DefaultAppendScanImageUseCase: AppendScanImageUseCase {
    let scanRepository: ScanRepository
    let imageStorage: ImageStorageService

    func execute(sessionID: UUID, imageData: Data) async throws -> ScanSession {
        let path = try await imageStorage.saveImageData(
            imageData,
            identifier: "scan-\(sessionID.uuidString)-\(UUID().uuidString)"
        )
        return try await scanRepository.appendImage(sessionID: sessionID, imagePath: path)
    }
}
