//
//  ItemDetailViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class ItemDetailViewModelTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var roomRepository: RoomRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var viewModel: ItemDetailViewModel!
    private var itemID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()

        let room = try await roomRepository.create(Room(homeID: UUID(), name: "Office"))
        let item = try await itemRepository.create(
            StoredItem(roomID: room.id, name: "Laptop", category: .electronics, locationDescription: "Desk")
        )
        itemID = item.id

        viewModel = ItemDetailViewModel(
            itemID: itemID,
            fetchDetail: DefaultFetchItemDetailUseCase(
                itemRepository: itemRepository,
                roomRepository: roomRepository,
                snapshotRepository: snapshotRepository
            ),
            deleteItem: DefaultDeleteItemUseCase(
                itemRepository: itemRepository,
                snapshotRepository: snapshotRepository,
                imageStorage: imageStorage
            ),
            toggleImportance: DefaultToggleItemImportanceUseCase(itemRepository: itemRepository),
            logger: OSAppLogger()
        )
    }

    func test_load_populatesItemAndRoom() async throws {
        await viewModel.load()

        let detail = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(detail.item.id, itemID)
        XCTAssertEqual(detail.room.name, "Office")
    }

    func test_toggleImportance_flipsFlagAndReloads() async throws {
        await viewModel.load()
        XCTAssertEqual(viewModel.state.value?.item.isImportant, false)

        await viewModel.toggleImportance()

        XCTAssertEqual(viewModel.state.value?.item.isImportant, true)
        XCTAssertNil(viewModel.mutationError)
    }

    func test_deleteItem_returnsTrueAndRemovesItem() async throws {
        let didDelete = await viewModel.deleteItem()
        XCTAssertTrue(didDelete)

        do {
            _ = try await itemRepository.fetchItem(itemID: itemID)
            XCTFail("Item should no longer exist")
        } catch {
            // expected
        }
    }
}
