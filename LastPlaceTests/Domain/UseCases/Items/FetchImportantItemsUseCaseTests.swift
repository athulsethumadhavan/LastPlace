//
//  FetchImportantItemsUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchImportantItemsUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var useCase: FetchImportantItemsUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataItemRepository(modelContainer: container)
        itemRepository = repository
        useCase = DefaultFetchImportantItemsUseCase(itemRepository: repository)
    }

    func test_execute_onlyReturnsImportantItems() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Passport", category: .documents, locationDescription: "Drawer", isImportant: true)
        )
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Pen", category: .other, locationDescription: "Desk", isImportant: false)
        )

        let result = try await useCase.execute()

        XCTAssertEqual(result.map(\.name), ["Passport"])
    }
}
