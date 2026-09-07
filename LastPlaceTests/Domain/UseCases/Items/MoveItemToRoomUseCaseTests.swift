//
//  MoveItemToRoomUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class MoveItemToRoomUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var roomRepository: RoomRepository!
    private var useCase: MoveItemToRoomUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        useCase = DefaultMoveItemToRoomUseCase(itemRepository: itemRepository, roomRepository: roomRepository)
    }

    func test_execute_movesItemToNewRoom() async throws {
        let homeID = UUID()
        let originRoom = try await roomRepository.create(Room(homeID: homeID, name: "Origin"))
        let destinationRoom = try await roomRepository.create(Room(homeID: homeID, name: "Destination"))
        let item = try await itemRepository.create(
            StoredItem(roomID: originRoom.id, name: "Box", category: .other, locationDescription: "Floor")
        )

        let moved = try await useCase.execute(itemID: item.id, toRoomID: destinationRoom.id)

        XCTAssertEqual(moved.roomID, destinationRoom.id)
    }

    func test_execute_toMissingRoom_throwsAndDoesNotMove() async throws {
        let homeID = UUID()
        let originRoom = try await roomRepository.create(Room(homeID: homeID, name: "Origin"))
        let item = try await itemRepository.create(
            StoredItem(roomID: originRoom.id, name: "Box", category: .other, locationDescription: "Floor")
        )

        do {
            _ = try await useCase.execute(itemID: item.id, toRoomID: UUID())
            XCTFail("Expected an error for a destination room that doesn't exist")
        } catch {
            // expected
        }

        let unchanged = try await itemRepository.fetchItem(itemID: item.id)
        XCTAssertEqual(unchanged.roomID, originRoom.id)
    }
}
