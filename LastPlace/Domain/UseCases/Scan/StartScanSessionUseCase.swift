//
//  StartScanSessionUseCase.swift
//  LastPlace
//

import Foundation

protocol StartScanSessionUseCase: Sendable {
    func execute(roomID: UUID) async throws -> ScanSession
}

struct DefaultStartScanSessionUseCase: StartScanSessionUseCase {
    let scanRepository: ScanRepository
    let roomRepository: RoomRepository

    func execute(roomID: UUID) async throws -> ScanSession {
        _ = try await roomRepository.fetchRoom(roomID: roomID)
        return try await scanRepository.startSession(roomID: roomID)
    }
}
