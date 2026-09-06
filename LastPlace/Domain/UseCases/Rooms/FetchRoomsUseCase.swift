//
//  FetchRoomsUseCase.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol FetchRoomsUseCase: Sendable {
    func execute(homeID: UUID) async throws -> [Room]
}

struct DefaultFetchRoomsUseCase: FetchRoomsUseCase {
    let roomRepository: RoomRepository

    func execute(homeID: UUID) async throws -> [Room] {
        try await roomRepository.fetchRooms(homeID: homeID)
    }
}
