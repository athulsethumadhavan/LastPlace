//
//  ToggleItemImportanceUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class ToggleItemImportanceUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var useCase: ToggleItemImportanceUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataItemRepository(modelContainer: container)
        itemRepository = repository
        useCase = DefaultToggleItemImportanceUseCase(itemRepository: repository)
    }

    func test_execute_flipsImportanceTwice() async throws {
        let item = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Passport", category: .documents, locationDescription: "Drawer")
        )
        XCTAssertFalse(item.isImportant)

        let toggled = try await useCase.execute(itemID: item.id)
        XCTAssertTrue(toggled.isImportant)

        let toggledBack = try await useCase.execute(itemID: item.id)
        XCTAssertFalse(toggledBack.isImportant)
    }
}
