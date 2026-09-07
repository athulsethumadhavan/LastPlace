//
//  FetchItemsForRoomUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchItemsForRoomUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var useCase: FetchItemsForRoomUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataItemRepository(modelContainer: container)
        itemRepository = repository
        useCase = DefaultFetchItemsForRoomUseCase(itemRepository: repository)
    }

    func test_execute_onlyReturnsItemsForRequestedRoom() async throws {
        let roomA = UUID()
        let roomB = UUID()
        _ = try await itemRepository.create(StoredItem(roomID: roomA, name: "Keys", category: .keys, locationDescription: "Hook"))
        _ = try await itemRepository.create(StoredItem(roomID: roomB, name: "Mug", category: .other, locationDescription: "Shelf"))

        let result = try await useCase.execute(roomID: roomA)

        XCTAssertEqual(result.map(\.name), ["Keys"])
    }
}
