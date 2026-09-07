//
//  ScanSaveItemViewModelTests.swift
//  LastPlaceTests
//

import XCTest
import CoreGraphics
@testable import LastPlace

@MainActor
final class ScanSaveItemViewModelTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var entitlementService: MockEntitlementService!
    private var analytics: MockAnalyticsService!
    private var roomID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        entitlementService = MockEntitlementService(status: .free)
        analytics = MockAnalyticsService()
        roomID = UUID()
    }

    private func makeViewModel(detection: DetectedObject) -> ScanSaveItemViewModel {
        ScanSaveItemViewModel(
            roomID: roomID,
            capturedAt: Date(),
            imageData: nil,
            detection: detection,
            confidence: 0.8,
            saveItem: DefaultSaveItemUseCase(
                itemRepository: itemRepository,
                snapshotRepository: snapshotRepository,
                imageStorage: MockImageStorageService(),
                entitlementService: entitlementService
            ),
            analytics: analytics,
            logger: OSAppLogger()
        )
    }

    func test_init_prefillsNameFromDetectionLabel() {
        let viewModel = makeViewModel(detection: DetectedObject(label: "Car Keys", confidence: 0.9, boundingBox: .zero))
        XCTAssertEqual(viewModel.name, "Car Keys")
    }

    func test_init_withoutSuggestedCategory_guessesFromLabelKeywords() {
        let viewModel = makeViewModel(detection: DetectedObject(label: "House Keys", confidence: 0.9, boundingBox: .zero))
        XCTAssertEqual(viewModel.category, .keys)
    }

    func test_init_withSuggestedCategory_usesItDirectly() {
        let viewModel = makeViewModel(
            detection: DetectedObject(label: "Something", confidence: 0.9, boundingBox: .zero, suggestedCategory: .documents)
        )
        XCTAssertEqual(viewModel.category, .documents)
    }

    func test_save_persistsItemAndLogsKeptSuggestionNaming() async throws {
        let viewModel = makeViewModel(detection: DetectedObject(label: "Car Keys", confidence: 0.9, boundingBox: .zero))

        let saved = await viewModel.save()
        let item = try XCTUnwrap(saved)

        XCTAssertEqual(item.name, "Car Keys")
        XCTAssertEqual(analytics.loggedEventNames(), ["item_saved", "item_named"])
    }

    func test_save_whenNameEdited_logsNamingOutcomeAsNone() async {
        let viewModel = makeViewModel(detection: DetectedObject(label: "Car Keys", confidence: 0.9, boundingBox: .zero))
        viewModel.name = "My House Keys"

        _ = await viewModel.save()

        XCTAssertEqual(analytics.loggedEventNames(), ["item_saved", "item_named"])
    }

    func test_save_onFreeTierAtLimit_showsPaywallInsteadOfError() async throws {
        entitlementService.currentStatus = EntitlementStatus(isPremium: false, remainingItemSlots: 0)
        let viewModel = makeViewModel(detection: DetectedObject(label: "Car Keys", confidence: 0.9, boundingBox: .zero))

        let saved = await viewModel.save()

        XCTAssertNil(saved)
        XCTAssertEqual(viewModel.paywallReason, .itemLimitReached)
        XCTAssertNil(viewModel.error)
    }

    func test_canSave_requiresNonBlankName() {
        let viewModel = makeViewModel(detection: DetectedObject(label: "Car Keys", confidence: 0.9, boundingBox: .zero))
        viewModel.name = "   "
        XCTAssertFalse(viewModel.canSave)
    }
}
