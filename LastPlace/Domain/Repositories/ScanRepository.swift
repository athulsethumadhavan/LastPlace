//
//  ScanRepository.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol ScanRepository: Sendable {
    func startSession(roomID: UUID) async throws -> ScanSession
    func fetchSession(id: UUID) async throws -> ScanSession
    func appendImage(sessionID: UUID, imagePath: String) async throws -> ScanSession
    func complete(sessionID: UUID) async throws -> ScanSession
    func cancel(sessionID: UUID) async throws
}
