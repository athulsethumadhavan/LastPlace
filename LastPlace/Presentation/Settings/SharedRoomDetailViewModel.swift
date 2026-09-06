//
//  SharedRoomDetailViewModel.swift
//  LastPlace
//
//  Read-only view of a room another account has shared with you. Pulled
//  live from Supabase every time this screen loads — never cached into
//  this device's local SwiftData store, since the data belongs to the
//  owner's account, not the viewer's.
//

import Foundation
import Observation

struct SharedRoomDetailContent: Sendable {
    let room: Room
    let items: [StoredItem]
    let ownerProfile: SharingProfile?
}

@Observable
@MainActor
final class SharedRoomDetailViewModel {
    let roomID: UUID
    let ownerID: UUID
    private(set) var state: LoadableState<SharedRoomDetailContent> = .idle

    private let roomSharingService: RoomSharingService
    private let logger: AppLogger

    init(roomID: UUID, ownerID: UUID, roomSharingService: RoomSharingService, logger: AppLogger) {
        self.roomID = roomID
        self.ownerID = ownerID
        self.roomSharingService = roomSharingService
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            async let detailTask = roomSharingService.fetchSharedRoomDetail(roomID: roomID)
            async let profileTask = roomSharingService.fetchProfile(userID: ownerID)
            let (detail, profile) = try await (detailTask, profileTask)
            state = .loaded(SharedRoomDetailContent(room: detail.room, items: detail.items, ownerProfile: profile))
        } catch {
            logger.error("Shared room detail load failed", error: error, category: "sharing")
            state = .failed(UserFacingError.from(error))
        }
    }

    /// Passed to `AsyncRemoteImage` for each item thumbnail — an on-demand
    /// Storage download, since `AsyncStoredImage`'s local file cache can
    /// never hold another account's images.
    func loadImageData(path: String) async throws -> Data {
        try await roomSharingService.loadSharedImageData(path: path, ownerID: ownerID)
    }
}
