//
//  DeleteAllDataUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class DeleteAllDataUseCaseTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var roomRepository: RoomRepository!
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var checklistRepository: ChecklistRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: DeleteAllDataUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        homeRepository = SwiftDataHomeRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        imageStorage = MockImageStorageService()

        let deleteRoom = DefaultDeleteRoomUseCase(
            roomRepository: roomRepository,
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage
        )
        let deleteChecklist = DefaultDeleteChecklistUseCase(checklistRepository: checklistRepository)

        useCase = DefaultDeleteAllDataUseCase(
            homeRepository: homeRepository,
            roomRepository: roomRepository,
            checklistRepository: checklistRepository,
            deleteRoom: deleteRoom,
            deleteChecklist: deleteChecklist
        )
    }

    func test_execute_wipesRoomsItemsAndChecklistsButKeepsHome() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let room = try await roomRepository.create(Room(homeID: home.id, name: "Kitchen"))
        _ = try await itemRepository.create(StoredItem(roomID: room.id, name: "Mug", category: .other, locationDescription: "Shelf"))
        _ = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))

        try await useCase.execute()

        let homes = try await homeRepository.fetchHomes()
        XCTAssertEqual(homes.map(\.id), [home.id])

        let rooms = try await roomRepository.fetchRooms(homeID: home.id)
        XCTAssertTrue(rooms.isEmpty)

        let checklists = try await checklistRepository.fetchChecklists()
        XCTAssertTrue(checklists.isEmpty)
    }

    func test_execute_onEmptyStore_doesNotThrow() async throws {
        try await useCase.execute()
    }
}
