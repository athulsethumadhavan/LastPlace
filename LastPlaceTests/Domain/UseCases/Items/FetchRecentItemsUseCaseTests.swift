//
//  FetchRecentItemsUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchRecentItemsUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var useCase: FetchRecentItemsUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataItemRepository(modelContainer: container)
        itemRepository = repository
        useCase = DefaultFetchRecentItemsUseCase(itemRepository: repository)
    }

    func test_execute_respectsLimit() async throws {
        for index in 0..<5 {
            _ = try await itemRepository.create(
                StoredItem(roomID: UUID(), name: "Item \(index)", category: .other, locationDescription: "Somewhere")
            )
        }

        let result = try await useCase.execute(limit: 3)
        XCTAssertEqual(result.count, 3)
    }

    func test_execute_withDefaultLimit_usesEight() async throws {
        for index in 0..<10 {
            _ = try await itemRepository.create(
                StoredItem(roomID: UUID(), name: "Item \(index)", category: .other, locationDescription: "Somewhere")
            )
        }

        let result = try await useCase.execute()
        XCTAssertEqual(result.count, 8)
    }
}
