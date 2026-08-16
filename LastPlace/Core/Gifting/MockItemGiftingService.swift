//
//  MockItemGiftingService.swift
//  LastPlace
//
//  In-memory ItemGiftingService for previews and `makePreview()`. Mirrors
//  `MockRoomSharingService`'s shape.
//

import Foundation

final class MockItemGiftingService: ItemGiftingService, @unchecked Sendable {
    var outgoing: [ItemGift] = []
    var incoming: [ItemGift] = []
    var profiles: [UUID: SharingProfile] = [:]
    var currentUserID: UUID = UUID()

    func giftItem(itemID: UUID, recipientEmail: String) async throws -> ItemGift {
        guard let recipient = profiles.first(where: { $0.value.email?.caseInsensitiveCompare(recipientEmail) == .orderedSame })?.key else {
            throw ItemGiftingError.noAccountFound
        }
        let gift = ItemGift(
            id: UUID(),
            fromUserID: currentUserID,
            toUserID: recipient,
            status: .pending,
            itemName: "Preview Item",
            itemCategory: .other,
            itemNotes: nil,
            itemLocationDescription: "",
            sourceImagePath: nil,
            createdAt: Date(),
            resolvedAt: nil,
            resolvedItemID: nil
        )
        outgoing.append(gift)
        return gift
    }

    func outgoingGifts() async throws -> [ItemGift] {
        outgoing
    }

    func incomingGifts() async throws -> [ItemGift] {
        incoming
    }

    func cancelGift(_ giftID: UUID) async throws {
        outgoing.removeAll { $0.id == giftID }
    }

    func declineGift(_ giftID: UUID) async throws {
        guard let index = incoming.firstIndex(where: { $0.id == giftID }) else { return }
        incoming[index].status = .declined
        incoming[index].resolvedAt = Date()
    }

    func acceptGift(_ giftID: UUID, intoRoomID roomID: UUID) async throws -> (item: StoredItem, imageData: Data?) {
        guard let index = incoming.firstIndex(where: { $0.id == giftID }) else {
            throw ItemGiftingError.alreadyResolved
        }
        let gift = incoming[index]
        let item = StoredItem(
            roomID: roomID,
            name: gift.itemName,
            category: gift.itemCategory,
            notes: gift.itemNotes,
            locationDescription: gift.itemLocationDescription,
            originSharedBy: gift.fromUserID
        )
        incoming[index].status = .accepted
        incoming[index].resolvedAt = Date()
        incoming[index].resolvedItemID = item.id
        return (item, nil)
    }

    func loadGiftImageData(sourcePath: String, senderID: UUID) async throws -> Data {
        Data()
    }

    func fetchProfile(userID: UUID) async throws -> SharingProfile? {
        profiles[userID]
    }

    func observeIncomingGifts() -> AsyncStream<[ItemGift]> {
        AsyncStream { continuation in
            continuation.yield(incoming)
            continuation.finish()
        }
    }
}
