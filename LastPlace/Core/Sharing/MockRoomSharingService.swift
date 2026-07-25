//
//  MockRoomSharingService.swift
//  LastPlace
//
//  In-memory RoomSharingService for previews and `makePreview()`. Mirrors
//  the pattern of `MockAuthService`/`MockImageStorageService` elsewhere in
//  Core — no network, deterministic seedable state.
//

import Foundation

final class MockRoomSharingService: RoomSharingService, @unchecked Sendable {
    var outgoingByRoom: [UUID: [RoomShare]] = [:]
    var incoming: [RoomShare] = []
    var profiles: [UUID: SharingProfile] = [:]
    var sharedRoomDetails: [UUID: (room: Room, items: [StoredItem])] = [:]
    var currentUserID: UUID = UUID()

    func inviteToRoom(roomID: UUID, inviteeEmail: String) async throws -> RoomShare {
        guard let invitee = profiles.first(where: { $0.value.email?.caseInsensitiveCompare(inviteeEmail) == .orderedSame })?.key else {
            throw RoomSharingError.noAccountFound
        }
        let share = RoomShare(
            id: UUID(),
            roomID: roomID,
            ownerID: currentUserID,
            sharedWithUserID: invitee,
            invitedAt: Date(),
            acceptedAt: nil
        )
        outgoingByRoom[roomID, default: []].append(share)
        return share
    }

    func outgoingShares(roomID: UUID) async throws -> [RoomShare] {
        outgoingByRoom[roomID] ?? []
    }

    func incomingShares() async throws -> [RoomShare] {
        incoming
    }

    func acceptShare(_ shareID: UUID) async throws {
        guard let index = incoming.firstIndex(where: { $0.id == shareID }) else { return }
        incoming[index].acceptedAt = Date()
    }

    func removeShare(_ shareID: UUID) async throws {
        incoming.removeAll { $0.id == shareID }
        for key in outgoingByRoom.keys {
            outgoingByRoom[key]?.removeAll { $0.id == shareID }
        }
    }

    func fetchProfile(userID: UUID) async throws -> SharingProfile? {
        profiles[userID]
    }

    func fetchSharedRoomDetail(roomID: UUID) async throws -> (room: Room, items: [StoredItem]) {
        guard let detail = sharedRoomDetails[roomID] else {
            throw RoomSharingError.fetchFailed(underlying: "No preview data for this shared room.")
        }
        return detail
    }

    func loadSharedImageData(path: String, ownerID: UUID) async throws -> Data {
        Data()
    }

    func observeIncomingShares() -> AsyncStream<[RoomShare]> {
        AsyncStream { continuation in
            continuation.yield(incoming)
            continuation.finish()
        }
    }
}
