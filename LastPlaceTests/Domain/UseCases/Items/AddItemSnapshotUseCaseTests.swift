//
//  AddItemSnapshotUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class AddItemSnapshotUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: AddItemSnapshotUseCase!
    private var itemID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        useCase = DefaultAddItemSnapshotUseCase(
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage
        )
        let item = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Keys", category: .keys, locationDescription: "Hook")
        )
        itemID = item.id
    }

    func test_execute_withoutImage_createsSnapshotWithNoImagePath() async throws {
        let snapshot = try await useCase.execute(
            AddItemSnapshotInput(itemID: itemID, locationDescription: "Drawer")
        )

        XCTAssertNil(snapshot.imagePath)
        XCTAssertEqual(snapshot.itemID, itemID)

        let stored = try await snapshotRepository.fetchSnapshots(itemID: itemID)
        XCTAssertEqual(stored.map(\.id), [snapshot.id])
    }

    func test_execute_withImage_persistsImageData() async throws {
        let imageData = Data([0x01, 0x02])
        let snapshot = try await useCase.execute(
            AddItemSnapshotInput(itemID: itemID, imageData: imageData, locationDescription: "Drawer", source: .scan)
        )

        let path = try XCTUnwrap(snapshot.imagePath)
        let stored = try await imageStorage.loadImageData(from: path)
        XCTAssertEqual(stored, imageData)
        XCTAssertEqual(snapshot.source, .scan)
    }

    func test_execute_inheritsRoomIDFromItem() async throws {
        let item = try await itemRepository.fetchItem(itemID: itemID)
        let snapshot = try await useCase.execute(
            AddItemSnapshotInput(itemID: itemID, locationDescription: "Drawer")
        )
        XCTAssertEqual(snapshot.roomID, item.roomID)
    }

    func test_execute_onMissingItem_throws() async throws {
        do {
            _ = try await useCase.execute(AddItemSnapshotInput(itemID: UUID(), locationDescription: "Nowhere"))
            XCTFail("Expected an error for an item that doesn't exist")
        } catch {
            // expected
        }
    }
}
