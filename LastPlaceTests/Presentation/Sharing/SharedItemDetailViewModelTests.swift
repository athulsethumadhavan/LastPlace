//
//  SharedItemDetailViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class SharedItemDetailViewModelTests: XCTestCase {
    private var roomSharingService: MockRoomSharingService!
    private var authService: MockAuthService!
    private var viewModel: SharedItemDetailViewModel!
    private var roomID: UUID!
    private var itemID: UUID!
    private var ownerID: UUID!
    private var currentUser: AuthUser!

    override func setUp() async throws {
        try await super.setUp()
        roomID = UUID()
        ownerID = UUID()
        currentUser = AuthUser(id: UUID(), email: "viewer@example.com")

        let item = StoredItem(id: UUID(), roomID: roomID, name: "Ladder", category: .tools, locationDescription: "Garage")
        itemID = item.id

        roomSharingService = MockRoomSharingService()
        roomSharingService.sharedRoomDetails[roomID] = (room: Room(homeID: UUID(), name: "Garage"), items: [item])
        roomSharingService.profiles[ownerID] = SharingProfile(id: ownerID, email: "owner@example.com", displayName: "Owner")

        authService = MockAuthService(user: currentUser)

        viewModel = SharedItemDetailViewModel(
            itemID: itemID,
            roomID: roomID,
            ownerID: ownerID,
            roomSharingService: roomSharingService,
            authService: authService,
            logger: OSAppLogger()
        )
    }

    func test_load_populatesItemHistoryAndOwnerProfile() async throws {
        await viewModel.load()

        let content = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(content.item.id, itemID)
        XCTAssertEqual(content.ownerProfile?.displayLabel, "Owner")
    }

    func test_load_whenOwnerRemovedTheItem_reportsFailure() async throws {
        roomSharingService.sharedRoomDetails[roomID] = (room: Room(homeID: UUID(), name: "Garage"), items: [])

        await viewModel.load()

        XCTAssertNotNil(viewModel.state.error)
    }

    func test_updateLocation_savesAndReturnsTrue() async throws {
        await viewModel.load()

        let didUpdate = await viewModel.updateLocation(to: "  Behind the door  ")

        XCTAssertTrue(didUpdate)
        let history = roomSharingService.historyByItem[itemID]
        XCTAssertEqual(history?.first?.locationDescription, "Behind the door")
    }

    func test_updateLocation_tooLong_returnsFalseWithoutCallingService() async throws {
        await viewModel.load()
        let tooLong = String(repeating: "a", count: StoredItem.locationMaxLength + 1)

        let didUpdate = await viewModel.updateLocation(to: tooLong)

        XCTAssertFalse(didUpdate)
        XCTAssertNotNil(viewModel.actionError)
        XCTAssertNil(roomSharingService.historyByItem[itemID])
    }
}
