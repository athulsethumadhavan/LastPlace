//
//  FetchItemDetailUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchItemDetailUseCase: Sendable {
    func execute(itemID: UUID) async throws -> ItemDetail
}

struct DefaultFetchItemDetailUseCase: FetchItemDetailUseCase {
    let itemRepository: ItemRepository
    let roomRepository: RoomRepository
    let snapshotRepository: SnapshotRepository

    func execute(itemID: UUID) async throws -> ItemDetail {
        let item = try await itemRepository.fetchItem(itemID: itemID)
        let room = try await roomRepository.fetchRoom(roomID: item.roomID)
        let snapshots = try await snapshotRepository.fetchSnapshots(itemID: itemID)
        return ItemDetail(item: item, room: room, snapshots: snapshots)
    }
}
