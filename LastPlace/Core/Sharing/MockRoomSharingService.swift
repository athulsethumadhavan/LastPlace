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
    var historyByItem: [UUID: [SharedItemHistoryEntry]] = [:]
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

    func sharedItemHistory(itemID: UUID) async throws -> [SharedItemHistoryEntry] {
        historyByItem[itemID] ?? []
    }

    /// Mirrors what the real RPC does to the caller's view of the world:
    /// the item's location and `lastSeenAt` change, a history entry appears
    /// attributed to the current user, and nothing else moves. Notably it
    /// does *not* touch name/notes/category/importance — a preview that
    /// allowed more than the database does would hide the very mistake this
    /// mock exists to catch.
    func updateSharedItemLocation(itemID: UUID, description: String) async throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        for (roomID, detail) in sharedRoomDetails {
            guard let index = detail.items.firstIndex(where: { $0.id == itemID }) else { continue }
            var items = detail.items
            items[index].locationDescription = trimmed
            items[index].lastSeenAt = Date()
            sharedRoomDetails[roomID] = (room: detail.room, items: items)
        }
        historyByItem[itemID, default: []].insert(
            SharedItemHistoryEntry(
                id: UUID(),
                locationDescription: trimmed,
                capturedAt: Date(),
                setBy: profiles[currentUserID]
            ),
            at: 0
        )
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
