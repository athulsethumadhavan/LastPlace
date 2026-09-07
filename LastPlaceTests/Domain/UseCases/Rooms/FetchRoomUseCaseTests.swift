//
//  FetchRoomUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchRoomUseCaseTests: XCTestCase {
    private var roomRepository: RoomRepository!
    private var useCase: FetchRoomUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataRoomRepository(modelContainer: container)
        roomRepository = repository
        useCase = DefaultFetchRoomUseCase(roomRepository: repository)
    }

    func test_execute_returnsMatchingRoom() async throws {
        let created = try await roomRepository.create(Room(homeID: UUID(), name: "Office"))
        let fetched = try await useCase.execute(roomID: created.id)
        XCTAssertEqual(fetched.id, created.id)
        XCTAssertEqual(fetched.name, "Office")
    }

    func test_execute_onMissingRoom_throws() async throws {
        do {
            _ = try await useCase.execute(roomID: UUID())
            XCTFail("Expected an error for a room that doesn't exist")
        } catch {
            // expected
        }
    }
}
