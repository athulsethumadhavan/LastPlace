//
//  DeleteAllDataUseCase.swift
//  LastPlace
//
//  Wipes every room (which cascades to its items, snapshots, and images via
//  `DeleteRoomUseCase`) and every checklist. Composes the existing per-entity
//  use cases rather than duplicating their cascade logic. The `Home` record
//  itself is left in place — there's no delete path for it and an empty home
//  is exactly the state a fresh install starts in anyway.
//
//  Known gap: scan sessions have no delete path in `ScanRepository` at all
//  (not something this use case introduces), so an abnormally-terminated
//  scan's images could theoretically survive a full wipe. Out of scope here.
//

import Foundation

protocol DeleteAllDataUseCase: Sendable {
    func execute() async throws
}

struct DefaultDeleteAllDataUseCase: DeleteAllDataUseCase {
    let homeRepository: HomeRepository
    let roomRepository: RoomRepository
    let checklistRepository: ChecklistRepository
    let deleteRoom: DeleteRoomUseCase
    let deleteChecklist: DeleteChecklistUseCase

    func execute() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let rooms = try await roomRepository.fetchRooms(homeID: home.id)
        for room in rooms {
            try await deleteRoom.execute(roomID: room.id)
        }

        let checklists = try await checklistRepository.fetchChecklists()
        for checklist in checklists {
            try await deleteChecklist.execute(id: checklist.id)
        }
    }
}
