//
//  UpdateRoomUseCase.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct UpdateRoomInput: Sendable {
    let room: Room
    let newCoverImageData: Data?

    init(room: Room, newCoverImageData: Data? = nil) {
        self.room = room
        self.newCoverImageData = newCoverImageData
    }
}

protocol UpdateRoomUseCase: Sendable {
    func execute(_ input: UpdateRoomInput) async throws -> Room
}

struct DefaultUpdateRoomUseCase: UpdateRoomUseCase {
    let roomRepository: RoomRepository
    let imageStorage: ImageStorageService

    func execute(_ input: UpdateRoomInput) async throws -> Room {
        var validated = try input.room.validated()
        validated.updatedAt = Date()

        if let newImageData = input.newCoverImageData {
            if let oldPath = validated.coverImagePath {
                try? await imageStorage.deleteImage(at: oldPath)
            }
            validated.coverImagePath = try await imageStorage.saveImageData(
                newImageData,
                identifier: "room-\(validated.id.uuidString)"
            )
        }

        return try await roomRepository.update(validated)
    }
}
