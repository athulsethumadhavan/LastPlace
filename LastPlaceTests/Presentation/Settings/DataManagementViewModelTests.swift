//
//  DataManagementViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class DataManagementViewModelTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var roomRepository: RoomRepository!
    private var itemRepository: ItemRepository!
    private var checklistRepository: ChecklistRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var viewModel: DataManagementViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        homeRepository = SwiftDataHomeRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()

        let deleteRoom = DefaultDeleteRoomUseCase(
            roomRepository: roomRepository,
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage
        )
        let deleteChecklist = DefaultDeleteChecklistUseCase(checklistRepository: checklistRepository)

        viewModel = DataManagementViewModel(
            fetchSummary: DefaultFetchDataSummaryUseCase(
                homeRepository: homeRepository,
                roomRepository: roomRepository,
                itemRepository: itemRepository,
                checklistRepository: checklistRepository
            ),
            deleteAllData: DefaultDeleteAllDataUseCase(
                homeRepository: homeRepository,
                roomRepository: roomRepository,
                checklistRepository: checklistRepository,
                deleteRoom: deleteRoom,
                deleteChecklist: deleteChecklist
            ),
            logger: OSAppLogger()
        )
    }

    func test_load_reportsCounts() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let room = try await roomRepository.create(Room(homeID: home.id, name: "Kitchen"))
        _ = try await itemRepository.create(StoredItem(roomID: room.id, name: "Mug", category: .other, locationDescription: "Shelf"))
        _ = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))

        await viewModel.load()

        let summary = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(summary.roomCount, 1)
        XCTAssertEqual(summary.itemCount, 1)
        XCTAssertEqual(summary.checklistCount, 1)
    }

    func test_deleteAll_wipesDataAndReloadsSummary() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let room = try await roomRepository.create(Room(homeID: home.id, name: "Kitchen"))
        _ = try await itemRepository.create(StoredItem(roomID: room.id, name: "Mug", category: .other, locationDescription: "Shelf"))

        let didDelete = await viewModel.deleteAll()

        XCTAssertTrue(didDelete)
        let summary = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(summary.roomCount, 0)
        XCTAssertEqual(summary.itemCount, 0)
        XCTAssertNil(viewModel.error)
    }
}
