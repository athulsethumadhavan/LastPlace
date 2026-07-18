//
//  CreateRoomViewModel.swift
//  LastPlace
//

import Foundation
import Observation

@Observable
@MainActor
final class CreateRoomViewModel {
    var name: String = ""
    var iconName: String = Room.defaultIconName
    var isSaving: Bool = false
    var error: UserFacingError?

    private let homeID: UUID
    private let createRoomUseCase: CreateRoomUseCase
    private let logger: AppLogger

    init(
        homeID: UUID,
        createRoom: CreateRoomUseCase,
        logger: AppLogger
    ) {
        self.homeID = homeID
        self.createRoomUseCase = createRoom
        self.logger = logger
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    /// Returns the newly-created `Room` so the caller can dismiss.
    func save() async -> Room? {
        guard canSave else { return nil }
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let room = try await createRoomUseCase.execute(
                CreateRoomInput(homeID: homeID, name: name, iconName: iconName, coverImageData: nil)
            )
            return room
        } catch {
            logger.error("Create room failed", error: error, category: "create-room")
            self.error = UserFacingError.from(error)
            return nil
        }
    }
}
