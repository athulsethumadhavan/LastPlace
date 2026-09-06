//
//  CreateRoomUseCase.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct CreateRoomInput: Sendable {
    let homeID: UUID
    let name: String
    let iconName: String
    let coverImageData: Data?

    init(
        homeID: UUID,
        name: String,
        iconName: String = Room.defaultIconName,
        coverImageData: Data? = nil
    ) {
        self.homeID = homeID
        self.name = name
        self.iconName = iconName
        self.coverImageData = coverImageData
    }
}

protocol CreateRoomUseCase: Sendable {
    func execute(_ input: CreateRoomInput) async throws -> Room
}

struct DefaultCreateRoomUseCase: CreateRoomUseCase {
    let roomRepository: RoomRepository
    let imageStorage: ImageStorageService

    func execute(_ input: CreateRoomInput) async throws -> Room {
        let draft = Room(homeID: input.homeID, name: input.name, iconName: input.iconName)
        let validated = try draft.validated()

        var coverPath: String?
        if let imageData = input.coverImageData {
            coverPath = try await imageStorage.saveImageData(imageData, identifier: "room-\(validated.id.uuidString)")
        }

        let room = Room(
            id: validated.id,
            homeID: validated.homeID,
            name: validated.name,
            iconName: validated.iconName,
            coverImagePath: coverPath,
            createdAt: validated.createdAt,
            updatedAt: validated.updatedAt
        )
        return try await roomRepository.create(room)
    }
}
