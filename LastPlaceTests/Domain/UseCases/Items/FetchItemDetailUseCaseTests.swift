//
//  FetchItemDetailUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchItemDetailUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var roomRepository: RoomRepository!
    private var snapshotRepository: SnapshotRepository!
    private var useCase: FetchItemDetailUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        useCase = DefaultFetchItemDetailUseCase(
            itemRepository: itemRepository,
            roomRepository: roomRepository,
            snapshotRepository: snapshotRepository
        )
    }

    func test_execute_combinesItemRoomAndSnapshots() async throws {
        let room = try await roomRepository.create(Room(homeID: UUID(), name: "Office"))
        let item = try await itemRepository.create(
            StoredItem(roomID: room.id, name: "Laptop", category: .electronics, locationDescription: "Desk")
        )
        _ = try await snapshotRepository.create(
            ItemSnapshot(itemID: item.id, roomID: room.id, locationDescription: "Desk", source: .manual)
        )

        let detail = try await useCase.execute(itemID: item.id)

        XCTAssertEqual(detail.item.id, item.id)
        XCTAssertEqual(detail.room.id, room.id)
        XCTAssertEqual(detail.snapshots.count, 1)
    }

    func test_execute_onMissingItem_throws() async throws {
        do {
            _ = try await useCase.execute(itemID: UUID())
            XCTFail("Expected an error for an item that doesn't exist")
        } catch {
            // expected
        }
    }
}
