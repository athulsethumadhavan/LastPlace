//
//  GiftItemViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class GiftItemViewModelTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var roomRepository: RoomRepository!
    private var snapshotRepository: SnapshotRepository!
    private var itemGiftingService: MockItemGiftingService!
    private var entitlementService: MockEntitlementService!
    private var syncEngine: MockPendingChangesSyncing!
    private var authService: MockAuthService!
    private var analytics: MockAnalyticsService!
    private var viewModel: GiftItemViewModel!
    private var itemID: UUID!
    private var recipientID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)

        let room = try await roomRepository.create(Room(homeID: UUID(), name: "Office"))
        let item = try await itemRepository.create(
            StoredItem(roomID: room.id, name: "Camera", category: .electronics, locationDescription: "Shelf")
        )
        itemID = item.id
        recipientID = UUID()

        itemGiftingService = MockItemGiftingService()
        itemGiftingService.profiles[recipientID] = SharingProfile(id: recipientID, email: "friend@example.com", displayName: nil)
        entitlementService = MockEntitlementService(status: .premium)
        syncEngine = MockPendingChangesSyncing()
        authService = MockAuthService(user: AuthUser(id: UUID(), email: "owner@example.com"))
        analytics = MockAnalyticsService()

        viewModel = GiftItemViewModel(
            itemID: itemID,
            fetchDetail: DefaultFetchItemDetailUseCase(
                itemRepository: itemRepository,
                roomRepository: roomRepository,
                snapshotRepository: snapshotRepository
            ),
            itemGiftingService: itemGiftingService,
            entitlementService: entitlementService,
            syncEngine: syncEngine,
            authService: authService,
            imageStorage: MockImageStorageService(),
            analytics: analytics,
            logger: OSAppLogger()
        )
    }

    func test_load_populatesItem() async throws {
        await viewModel.load()
        XCTAssertEqual(viewModel.state.value?.id, itemID)
    }

    func test_canSend_requiresPlausibleEmail() {
        XCTAssertFalse(viewModel.canSend)
        viewModel.recipientEmail = "not-an-email"
        XCTAssertFalse(viewModel.canSend)
        viewModel.recipientEmail = "friend@example.com"
        XCTAssertTrue(viewModel.canSend)
    }

    func test_send_onPremium_syncsFirstThenSendsAndLogsAnalytics() async {
        viewModel.recipientEmail = "friend@example.com"

        viewModel.send()
        await waitUntil { !self.viewModel.isSending }

        XCTAssertEqual(syncEngine.syncCallCount, 1)
        XCTAssertNotNil(viewModel.sentGift)
        XCTAssertEqual(analytics.loggedEventNames(), ["gift_sent"])
        XCTAssertNil(viewModel.paywallReason)
    }

    func test_send_onFreeTier_showsPaywallWithoutSending() async {
        entitlementService.currentStatus = .free
        viewModel.recipientEmail = "friend@example.com"

        viewModel.send()
        await waitUntil { !self.viewModel.isSending }

        XCTAssertEqual(viewModel.paywallReason, .sendGift)
        XCTAssertNil(viewModel.sentGift)
        XCTAssertEqual(syncEngine.syncCallCount, 0)
        XCTAssertTrue(analytics.loggedEvents.isEmpty)
    }

    func test_send_toUnknownRecipient_setsSendError() async {
        viewModel.recipientEmail = "nobody@example.com"

        viewModel.send()
        await waitUntil { !self.viewModel.isSending }

        XCTAssertNotNil(viewModel.sendError)
        XCTAssertNil(viewModel.sentGift)
    }
}
