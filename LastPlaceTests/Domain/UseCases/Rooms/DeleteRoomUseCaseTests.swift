//
//  DeleteRoomUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class DeleteRoomUseCaseTests: XCTestCase {
    private var roomRepository: RoomRepository!
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: DeleteRoomUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        useCase = DefaultDeleteRoomUseCase(
            roomRepository: roomRepository,
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage
        )
    }

    func test_execute_cascadesToItemsSnapshotsAndImages() async throws {
        let coverData = Data([0xAA])
        let coverPath = try await imageStorage.saveImageData(coverData, identifier: "room-cover")
        let room = try await roomRepository.create(Room(homeID: UUID(), name: "Garage", coverImagePath: coverPath))

        let itemImageData = Data([0xBB])
        let itemImagePath = try await imageStorage.saveImageData(itemImageData, identifier: "item")
        let item = try await itemRepository.create(
            StoredItem(roomID: room.id, name: "Bike", category: .tools, imagePath: itemImagePath, locationDescription: "Corner")
        )

        let snapshotImageData = Data([0xCC])
        let snapshotImagePath = try await imageStorage.saveImageData(snapshotImageData, identifier: "snapshot")
        _ = try await snapshotRepository.create(
            ItemSnapshot(itemID: item.id, roomID: room.id, imagePath: snapshotImagePath, locationDescription: "Corner", source: .manual)
        )

        try await useCase.execute(roomID: room.id)

        do {
            _ = try await roomRepository.fetchRoom(roomID: room.id)
            XCTFail("Room should no longer exist")
        } catch {
            // expected
        }

        let remainingItems = try await itemRepository.fetchItems(roomID: room.id)
        XCTAssertTrue(remainingItems.isEmpty)

        let remainingSnapshots = try await snapshotRepository.fetchSnapshots(itemID: item.id)
        XCTAssertTrue(remainingSnapshots.isEmpty)

        let imagesStillExist = await [
            imageStorage.imageExists(at: coverPath),
            imageStorage.imageExists(at: itemImagePath),
            imageStorage.imageExists(at: snapshotImagePath)
        ]
        XCTAssertEqual(imagesStillExist, [false, false, false])
    }

    func test_execute_onMissingRoom_throws() async throws {
        do {
            try await useCase.execute(roomID: UUID())
            XCTFail("Expected an error for a room that doesn't exist")
        } catch {
            // expected
        }
    }
}
