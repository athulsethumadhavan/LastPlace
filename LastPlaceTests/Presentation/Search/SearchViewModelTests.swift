//
//  SearchViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class SearchViewModelTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var analytics: MockAnalyticsService!
    private var viewModel: SearchViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        analytics = MockAnalyticsService()
        viewModel = SearchViewModel(
            searchItems: DefaultSearchItemsUseCase(itemRepository: itemRepository, suggestedLimit: 5),
            analytics: analytics,
            logger: OSAppLogger()
        )
    }

    func test_load_withNoQuery_showsSuggestedFallbackWithoutLoggingAnalytics() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Passport", category: .documents, locationDescription: "Drawer", isImportant: true)
        )

        await viewModel.load()

        let results = try XCTUnwrap(viewModel.state.value)
        XCTAssertFalse(results.hasMatches)
        XCTAssertFalse(results.suggested.isEmpty)
        XCTAssertTrue(analytics.loggedEvents.isEmpty, "A blank-query load isn't a search the person performed")
    }

    func test_refresh_withMatchingQuery_logsSearchPerformedWithResultCount() async throws {
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Car Keys", category: .keys, locationDescription: "Hook")
        )
        viewModel.query = "keys"

        await viewModel.refresh()

        let results = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(results.matches.map(\.name), ["Car Keys"])
        XCTAssertEqual(analytics.loggedEventNames(), ["search_performed"])
    }

    func test_refresh_withNoResults_reportsEmptyState() async throws {
        viewModel.query = "nonexistent-xyz"
        await viewModel.refresh()

        guard case .empty = viewModel.state else {
            return XCTFail("Expected .empty state for a query with no matches and no suggestions")
        }
    }
}
