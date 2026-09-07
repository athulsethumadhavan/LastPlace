//
//  CreateRoomViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class CreateRoomViewModelTests: XCTestCase {
    private var roomRepository: RoomRepository!
    private var analytics: MockAnalyticsService!
    private var viewModel: CreateRoomViewModel!
    private var homeID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        analytics = MockAnalyticsService()
        homeID = UUID()
        viewModel = CreateRoomViewModel(
            homeID: homeID,
            createRoom: DefaultCreateRoomUseCase(roomRepository: roomRepository, imageStorage: MockImageStorageService()),
            analytics: analytics,
            logger: OSAppLogger()
        )
    }

    func test_canSave_requiresNonBlankName() {
        XCTAssertFalse(viewModel.canSave)
        viewModel.name = "   "
        XCTAssertFalse(viewModel.canSave)
        viewModel.name = "Kitchen"
        XCTAssertTrue(viewModel.canSave)
    }

    func test_save_createsRoomAndLogsAnalytics() async throws {
        viewModel.name = "Kitchen"

        let saved = await viewModel.save()
        let room = try XCTUnwrap(saved)

        XCTAssertEqual(room.name, "Kitchen")
        XCTAssertEqual(room.homeID, homeID)
        XCTAssertEqual(analytics.loggedEventNames(), ["room_created"])

        let all = try await roomRepository.fetchRooms(homeID: homeID)
        XCTAssertEqual(all.map(\.id), [room.id])
    }

    func test_save_withBlankName_returnsNilAndDoesNotSave() async throws {
        let saved = await viewModel.save()
        XCTAssertNil(saved)

        let all = try await roomRepository.fetchRooms(homeID: homeID)
        XCTAssertTrue(all.isEmpty)
        XCTAssertTrue(analytics.loggedEvents.isEmpty)
    }
}
