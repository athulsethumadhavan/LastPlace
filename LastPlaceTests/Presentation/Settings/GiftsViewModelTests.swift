//
//  GiftsViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class GiftsViewModelTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var roomRepository: RoomRepository!
    private var itemRepository: ItemRepository!
    private var itemGiftingService: MockItemGiftingService!
    private var entitlementService: MockEntitlementService!
    private var syncEngine: MockPendingChangesSyncing!
    private var authService: MockAuthService!
    private var analytics: MockAnalyticsService!
    private var onAcceptedCallCount: Int!
    private var viewModel: GiftsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        homeRepository = SwiftDataHomeRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)

        itemGiftingService = MockItemGiftingService()
        entitlementService = MockEntitlementService(status: .free)
        syncEngine = MockPendingChangesSyncing()
        authService = MockAuthService(user: AuthUser(id: UUID(), email: "person@example.com"))
        analytics = MockAnalyticsService()
        onAcceptedCallCount = 0

        viewModel = GiftsViewModel(
            itemGiftingService: itemGiftingService,
            entitlementService: entitlementService,
            homeRepository: homeRepository,
            roomRepository: roomRepository,
            itemRepository: itemRepository,
            imageStorage: MockImageStorageService(),
            syncEngine: syncEngine,
            authService: authService,
            analytics: analytics,
            logger: OSAppLogger(),
            onAccepted: { [weak self] in self?.onAcceptedCallCount += 1 }
        )
    }

    private func makeGift(status: ItemGiftStatus, fromUserID: UUID = UUID(), toUserID: UUID = UUID()) -> ItemGift {
        ItemGift(
            id: UUID(),
            fromUserID: fromUserID,
            toUserID: toUserID,
            status: status,
            itemName: "Camera",
            itemCategory: .electronics,
            itemNotes: nil,
            itemLocationDescription: "Shelf",
            sourceImagePath: nil,
            createdAt: Date(),
            resolvedAt: nil,
            resolvedItemID: nil
        )
    }

    func test_load_splitsPendingAndResolvedIncomingGifts() async {
        let pending = makeGift(status: .pending)
        let declined = makeGift(status: .declined)
        itemGiftingService.incoming = [pending, declined]

        await viewModel.load()

        XCTAssertEqual(viewModel.pendingIncoming.map(\.gift.id), [pending.id])
        XCTAssertEqual(viewModel.resolvedIncoming.map(\.gift.id), [declined.id])
    }

    func test_fetchRoomsForAccept_listsDefaultHomeRooms() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let room = try await roomRepository.create(Room(homeID: home.id, name: "Living Room"))

        let rooms = try await viewModel.fetchRoomsForAccept()

        XCTAssertEqual(rooms.map(\.id), [room.id])
    }

    func test_accept_createsLocalItemAndNotifiesCaller() async throws {
        let gift = makeGift(status: .pending)
        itemGiftingService.incoming = [gift]
        await viewModel.load()
        let home = try await homeRepository.fetchDefaultHome()
        let room = try await roomRepository.create(Room(homeID: home.id, name: "Living Room"))

        viewModel.accept(gift.id, intoRoomID: room.id)
        await waitUntil { self.viewModel.mutatingGiftID == nil }

        XCTAssertEqual(syncEngine.syncCallCount, 1)
        XCTAssertEqual(onAcceptedCallCount, 1)
        XCTAssertEqual(analytics.loggedEventNames(), ["gift_accepted", "item_saved"])
        let items = try await itemRepository.fetchItems(roomID: room.id)
        XCTAssertEqual(items.map(\.name), ["Camera"])
        XCTAssertNil(viewModel.actionError)
        XCTAssertNil(viewModel.paywallReason)
    }

    func test_decline_marksGiftDeclinedAndRefreshes() async throws {
        let gift = makeGift(status: .pending)
        itemGiftingService.incoming = [gift]
        await viewModel.load()

        viewModel.decline(gift.id)
        await waitUntil { self.viewModel.mutatingGiftID == nil }

        XCTAssertEqual(viewModel.resolvedIncoming.map(\.gift.id), [gift.id])
        XCTAssertTrue(viewModel.pendingIncoming.isEmpty)
    }

    func test_cancel_removesOutgoingGift() async throws {
        let gift = makeGift(status: .pending)
        itemGiftingService.outgoing = [gift]
        await viewModel.load()
        XCTAssertEqual(viewModel.outgoing.map(\.gift.id), [gift.id])

        viewModel.cancel(gift.id)
        await waitUntil { self.viewModel.mutatingGiftID == nil }

        XCTAssertTrue(viewModel.outgoing.isEmpty)
    }
}
