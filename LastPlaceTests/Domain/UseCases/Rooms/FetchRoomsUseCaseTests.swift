//
//  FetchRoomsUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchRoomsUseCaseTests: XCTestCase {
    private var roomRepository: RoomRepository!
    private var useCase: FetchRoomsUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataRoomRepository(modelContainer: container)
        roomRepository = repository
        useCase = DefaultFetchRoomsUseCase(roomRepository: repository)
    }

    func test_execute_onlyReturnsRoomsForRequestedHome() async throws {
        let homeA = UUID()
        let homeB = UUID()
        _ = try await roomRepository.create(Room(homeID: homeA, name: "Kitchen"))
        _ = try await roomRepository.create(Room(homeID: homeA, name: "Bedroom"))
        _ = try await roomRepository.create(Room(homeID: homeB, name: "Garage"))

        let result = try await useCase.execute(homeID: homeA)

        XCTAssertEqual(Set(result.map(\.name)), ["Kitchen", "Bedroom"])
    }

    func test_execute_withNoRooms_returnsEmpty() async throws {
        let result = try await useCase.execute(homeID: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}
