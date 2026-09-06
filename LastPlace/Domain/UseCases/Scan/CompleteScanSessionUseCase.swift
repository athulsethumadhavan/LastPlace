//
//  CompleteScanSessionUseCase.swift
//  LastPlace
//

import Foundation

protocol CompleteScanSessionUseCase: Sendable {
    func execute(sessionID: UUID) async throws -> ScanSession
}

struct DefaultCompleteScanSessionUseCase: CompleteScanSessionUseCase {
    let scanRepository: ScanRepository

    func execute(sessionID: UUID) async throws -> ScanSession {
        try await scanRepository.complete(sessionID: sessionID)
    }
}
