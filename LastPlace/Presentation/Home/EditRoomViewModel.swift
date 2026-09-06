//
//  EditRoomViewModel.swift
//  LastPlace
//
//  Two-phase like `UpdateItemLocationViewModel`: load the existing room to
//  pre-fill the form, then save via `UpdateRoomUseCase`. Only the name and
//  icon are editable here — cover image re-shoots go through the scan flow.
//

import Foundation
import Observation

@Observable
@MainActor
final class EditRoomViewModel {
    let roomID: UUID
    var name: String = ""
    var iconName: String = Room.defaultIconName
    private(set) var loadState: LoadableState<Room> = .idle
    private(set) var isSaving: Bool = false
    var error: UserFacingError?

    private let fetchRoomUseCase: FetchRoomUseCase
    private let updateRoomUseCase: UpdateRoomUseCase
    private let logger: AppLogger

    init(
        roomID: UUID,
        fetchRoom: FetchRoomUseCase,
        updateRoom: UpdateRoomUseCase,
        logger: AppLogger
    ) {
        self.roomID = roomID
        self.fetchRoomUseCase = fetchRoom
        self.updateRoomUseCase = updateRoom
        self.logger = logger
    }

    var canSave: Bool {
        guard case .loaded(let room) = loadState, !isSaving else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed != room.name || iconName != room.iconName
    }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        do {
            let room = try await fetchRoomUseCase.execute(roomID: roomID)
            name = room.name
            iconName = room.iconName
            loadState = .loaded(room)
        } catch {
            logger.error("Edit room load failed", error: error, category: "edit-room")
            loadState = .failed(UserFacingError.from(error))
        }
    }

    /// Returns `true` on success so the view can pop.
    func save() async -> Bool {
        guard case .loaded(var room) = loadState, canSave else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }

        room.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        room.iconName = iconName

        do {
            let updated = try await updateRoomUseCase.execute(UpdateRoomInput(room: room))
            loadState = .loaded(updated)
            return true
        } catch {
            logger.error("Edit room save failed", error: error, category: "edit-room")
            self.error = UserFacingError.from(error)
            return false
        }
    }
}
