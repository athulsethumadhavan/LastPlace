//
//  RoomRepository.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol RoomRepository: Sendable {
    func fetchRooms(homeID: UUID) async throws -> [Room]
    func fetchRoom(roomID: UUID) async throws -> Room
    func create(_ room: Room) async throws -> Room
    func update(_ room: Room) async throws -> Room
    func delete(roomID: UUID) async throws
}
