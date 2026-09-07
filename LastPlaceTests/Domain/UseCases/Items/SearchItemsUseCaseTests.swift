//
//  SearchItemsUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class SearchItemsUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var useCase: SearchItemsUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataItemRepository(modelContainer: container)
        itemRepository = repository
        useCase = DefaultSearchItemsUseCase(itemRepository: repository, suggestedLimit: 5)
    }

    func test_execute_withMatchingQuery_returnsOnlyMatches() async throws {
        _ = try await itemRepository.create(StoredItem(roomID: UUID(), name: "Car Keys", category: .keys, locationDescription: "Hook"))
        _ = try await itemRepository.create(StoredItem(roomID: UUID(), name: "Passport", category: .documents, locationDescription: "Drawer"))

        let results = try await useCase.execute(query: "keys")

        XCTAssertTrue(results.hasMatches)
        XCTAssertEqual(results.matches.map(\.name), ["Car Keys"])
        XCTAssertTrue(results.suggested.isEmpty)
    }

    func test_execute_withBlankQuery_returnsSuggestedFallback() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Passport", category: .documents, locationDescription: "Drawer", isImportant: true)
        )

        let results = try await useCase.execute(query: "   ")

        XCTAssertFalse(results.hasMatches)
        XCTAssertFalse(results.suggested.isEmpty)
    }

    func test_execute_withNoMatches_fallsBackToSuggestions() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Passport", category: .documents, locationDescription: "Drawer", isImportant: true)
        )

        let results = try await useCase.execute(query: "nonexistent-item-xyz")

        XCTAssertTrue(results.matches.isEmpty)
        XCTAssertEqual(results.suggested.map(\.name), ["Passport"])
    }

    func test_execute_withNoItemsAtAll_returnsEmptyResults() async throws {
        let results = try await useCase.execute(query: "")
        XCTAssertTrue(results.isEmpty)
    }
}
