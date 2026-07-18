//
//  FetchDataSummaryUseCase.swift
//  LastPlace
//
//  Powers the "what's saved" summary on the Data Management screen. Item
//  count is summed per room since `ItemRepository` has no "all items"
//  fetch — acceptable for the MVP dataset size (see `SwiftDataItemRepository`).
//

import Foundation

struct DataSummary: Sendable {
    let roomCount: Int
    let itemCount: Int
    let checklistCount: Int
}

protocol FetchDataSummaryUseCase: Sendable {
    func execute() async throws -> DataSummary
}

struct DefaultFetchDataSummaryUseCase: FetchDataSummaryUseCase {
    let homeRepository: HomeRepository
    let roomRepository: RoomRepository
    let itemRepository: ItemRepository
    let checklistRepository: ChecklistRepository

    func execute() async throws -> DataSummary {
        let home = try await homeRepository.fetchDefaultHome()
        let rooms = try await roomRepository.fetchRooms(homeID: home.id)

        var itemCount = 0
        for room in rooms {
            itemCount += try await itemRepository.fetchItems(roomID: room.id).count
        }

        let checklists = try await checklistRepository.fetchChecklists()

        return DataSummary(
            roomCount: rooms.count,
            itemCount: itemCount,
            checklistCount: checklists.count
        )
    }
}
