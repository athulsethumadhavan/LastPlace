//
//  FetchRoomUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchRoomUseCase: Sendable {
    func execute(roomID: UUID) async throws -> Room
}

struct DefaultFetchRoomUseCase: FetchRoomUseCase {
    let roomRepository: RoomRepository

    func execute(roomID: UUID) async throws -> Room {
        try await roomRepository.fetchRoom(roomID: roomID)
    }
}
