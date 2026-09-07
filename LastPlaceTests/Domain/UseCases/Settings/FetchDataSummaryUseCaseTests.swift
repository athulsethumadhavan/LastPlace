//
//  FetchDataSummaryUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchDataSummaryUseCaseTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var roomRepository: RoomRepository!
    private var itemRepository: ItemRepository!
    private var checklistRepository: ChecklistRepository!
    private var useCase: FetchDataSummaryUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        homeRepository = SwiftDataHomeRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        useCase = DefaultFetchDataSummaryUseCase(
            homeRepository: homeRepository,
            roomRepository: roomRepository,
            itemRepository: itemRepository,
            checklistRepository: checklistRepository
        )
    }

    func test_execute_countsRoomsItemsAndChecklists() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let roomA = try await roomRepository.create(Room(homeID: home.id, name: "Kitchen"))
        let roomB = try await roomRepository.create(Room(homeID: home.id, name: "Garage"))
        _ = try await itemRepository.create(StoredItem(roomID: roomA.id, name: "Mug", category: .other, locationDescription: "Shelf"))
        _ = try await itemRepository.create(StoredItem(roomID: roomB.id, name: "Bike", category: .tools, locationDescription: "Corner"))
        _ = try await itemRepository.create(StoredItem(roomID: roomB.id, name: "Helmet", category: .other, locationDescription: "Shelf"))
        _ = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))

        let summary = try await useCase.execute()

        XCTAssertEqual(summary.roomCount, 2)
        XCTAssertEqual(summary.itemCount, 3)
        XCTAssertEqual(summary.checklistCount, 1)
    }

    func test_execute_onFreshInstall_returnsZeroes() async throws {
        let summary = try await useCase.execute()
        XCTAssertEqual(summary.roomCount, 0)
        XCTAssertEqual(summary.itemCount, 0)
        XCTAssertEqual(summary.checklistCount, 0)
    }
}
