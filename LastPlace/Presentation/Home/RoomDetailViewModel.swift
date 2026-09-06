//
//  RoomDetailViewModel.swift
//  LastPlace
//

import Foundation
import Observation

struct RoomDetailContent: Sendable {
    let room: Room
    let items: [StoredItem]
}

@Observable
@MainActor
final class RoomDetailViewModel {
    let roomID: UUID
    private(set) var state: LoadableState<RoomDetailContent> = .idle
    private(set) var isDeleting: Bool = false
    var deletionError: UserFacingError?

    private let fetchRoomUseCase: FetchRoomUseCase
    private let fetchItemsUseCase: FetchItemsForRoomUseCase
    private let deleteRoomUseCase: DeleteRoomUseCase
    private let logger: AppLogger

    init(
        roomID: UUID,
        fetchRoom: FetchRoomUseCase,
        fetchItems: FetchItemsForRoomUseCase,
        deleteRoom: DeleteRoomUseCase,
        logger: AppLogger
    ) {
        self.roomID = roomID
        self.fetchRoomUseCase = fetchRoom
        self.fetchItemsUseCase = fetchItems
        self.deleteRoomUseCase = deleteRoom
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            async let roomTask = fetchRoomUseCase.execute(roomID: roomID)
            async let itemsTask = fetchItemsUseCase.execute(roomID: roomID)
            let (room, items) = try await (roomTask, itemsTask)
            state = .loaded(RoomDetailContent(room: room, items: items))
        } catch {
            logger.error("Room detail load failed", error: error, category: "room-detail")
            state = .failed(UserFacingError.from(error))
        }
    }

    /// Returns `true` on successful delete so the view can pop.
    func deleteRoom() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        deletionError = nil
        defer { isDeleting = false }

        do {
            try await deleteRoomUseCase.execute(roomID: roomID)
            return true
        } catch {
            logger.error("Room delete failed", error: error, category: "room-detail")
            deletionError = UserFacingError.from(error)
            return false
        }
    }
}
