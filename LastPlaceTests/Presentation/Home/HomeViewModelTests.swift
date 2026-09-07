//
//  HomeViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var roomRepository: RoomRepository!
    private var itemRepository: ItemRepository!
    private var roomSharingService: MockRoomSharingService!
    private var entitlementService: MockEntitlementService!
    private var viewModel: HomeViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        homeRepository = SwiftDataHomeRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        roomSharingService = MockRoomSharingService()
        entitlementService = MockEntitlementService(status: .free)

        viewModel = HomeViewModel(
            fetchDefaultHome: DefaultFetchDefaultHomeUseCase(homeRepository: homeRepository),
            fetchRooms: DefaultFetchRoomsUseCase(roomRepository: roomRepository),
            fetchRecent: DefaultFetchRecentItemsUseCase(itemRepository: itemRepository),
            fetchImportant: DefaultFetchImportantItemsUseCase(itemRepository: itemRepository),
            roomSharingService: roomSharingService,
            itemRepository: itemRepository,
            entitlementService: entitlementService,
            configuration: .default,
            logger: OSAppLogger()
        )
    }

    func test_load_populatesHomeRoomsAndImportantItems() async throws {
        let home = try await homeRepository.fetchDefaultHome()
        let room = try await roomRepository.create(Room(homeID: home.id, name: "Kitchen"))
        _ = try await itemRepository.create(
            StoredItem(roomID: room.id, name: "Mug", category: .other, locationDescription: "Shelf", isImportant: true)
        )

        await viewModel.load()

        let content = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(content.home.id, home.id)
        XCTAssertEqual(content.rooms.map(\.name), ["Kitchen"])
        XCTAssertEqual(content.importantItems.map(\.name), ["Mug"])
    }

    func test_load_onFreeTier_reportsItemUsage() async throws {
        entitlementService.currentStatus = EntitlementStatus(isPremium: false, remainingItemSlots: 7)
        _ = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Keys", category: .keys, locationDescription: "Hook")
        )

        await viewModel.load()

        let usage = try XCTUnwrap(viewModel.state.value?.itemUsage)
        XCTAssertEqual(usage.used, EntitlementStatus.freeItemLimit - 7)
        XCTAssertEqual(usage.limit, EntitlementStatus.freeItemLimit)
    }

    func test_load_onPremium_reportsNoItemUsage() async throws {
        entitlementService.currentStatus = .premium
        await viewModel.load()
        XCTAssertNil(viewModel.state.value?.itemUsage)
    }

    func test_load_includesOnlyAcceptedSharedRooms() async throws {
        let ownerID = UUID()
        let acceptedRoomID = UUID()
        roomSharingService.incoming = [
            RoomShare(
                id: UUID(), roomID: acceptedRoomID, ownerID: ownerID,
                sharedWithUserID: roomSharingService.currentUserID, invitedAt: Date(), acceptedAt: Date()
            ),
            RoomShare(
                id: UUID(), roomID: UUID(), ownerID: ownerID,
                sharedWithUserID: roomSharingService.currentUserID, invitedAt: Date(), acceptedAt: nil
            )
        ]
        roomSharingService.sharedRoomDetails[acceptedRoomID] = (room: Room(homeID: UUID(), name: "Shared Garage"), items: [])
        roomSharingService.profiles[ownerID] = SharingProfile(id: ownerID, email: "owner@example.com", displayName: "Owner")

        await viewModel.load()

        let content = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(content.sharedRooms.map(\.room.name), ["Shared Garage"])
        XCTAssertEqual(content.sharedRooms.first?.ownerLabel, "Owner")
    }

    func test_refresh_reloadsAfterRoomIsAdded() async throws {
        await viewModel.load()
        let home = try XCTUnwrap(viewModel.state.value?.home)
        _ = try await roomRepository.create(Room(homeID: home.id, name: "New Room"))

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state.value?.rooms.map(\.name), ["New Room"])
    }
}
