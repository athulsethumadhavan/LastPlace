//
//  ItemRepositorySearchTests.swift
//  LastPlaceTests
//
//  Use case tests already exercise search-by-name; this covers the other
//  fields `ItemRepository.search` documents (category, room name, location,
//  notes) plus `countItems`, neither of which has a dedicated use case of
//  its own to test through.
//

import XCTest
@testable import LastPlace

final class ItemRepositorySearchTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var roomRepository: RoomRepository!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
    }

    func test_search_matchesByCategoryDisplayName() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "House Keys", category: .keys, locationDescription: "Hook")
        )

        let results = try await itemRepository.search(query: "Keys")
        XCTAssertEqual(results.map(\.name), ["House Keys"])
    }

    func test_search_matchesByRoomName() async throws {
        let room = try await roomRepository.create(Room(homeID: UUID(), name: "Garage"))
        _ = try await itemRepository.create(
            StoredItem(roomID: room.id, name: "Bike", category: .tools, locationDescription: "Corner")
        )

        let results = try await itemRepository.search(query: "Garage")
        XCTAssertEqual(results.map(\.name), ["Bike"])
    }

    func test_search_matchesByLocationDescription() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Umbrella", category: .other, locationDescription: "Behind the front door")
        )

        let results = try await itemRepository.search(query: "front door")
        XCTAssertEqual(results.map(\.name), ["Umbrella"])
    }

    func test_search_matchesByNotes() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Toolbox", category: .tools, notes: "Missing the hammer", locationDescription: "Shelf")
        )

        let results = try await itemRepository.search(query: "hammer")
        XCTAssertEqual(results.map(\.name), ["Toolbox"])
    }

    func test_countItems_reflectsCreatesAndDeletes() async throws {
        let first = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "A", category: .other, locationDescription: "Here")
        )
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "B", category: .other, locationDescription: "Here")
        )

        var count = try await itemRepository.countItems()
        XCTAssertEqual(count, 2)

        try await itemRepository.delete(itemID: first.id)
        count = try await itemRepository.countItems()
        XCTAssertEqual(count, 1)
    }
}
