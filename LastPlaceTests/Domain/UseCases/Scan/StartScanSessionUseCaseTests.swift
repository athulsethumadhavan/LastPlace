//
//  StartScanSessionUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class StartScanSessionUseCaseTests: XCTestCase {
    private var scanRepository: ScanRepository!
    private var roomRepository: RoomRepository!
    private var useCase: StartScanSessionUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        scanRepository = SwiftDataScanRepository(modelContainer: container)
        roomRepository = SwiftDataRoomRepository(modelContainer: container)
        useCase = DefaultStartScanSessionUseCase(scanRepository: scanRepository, roomRepository: roomRepository)
    }

    func test_execute_startsSessionForExistingRoom() async throws {
        let room = try await roomRepository.create(Room(homeID: UUID(), name: "Garage"))

        let session = try await useCase.execute(roomID: room.id)

        XCTAssertEqual(session.roomID, room.id)
        XCTAssertEqual(session.status, .inProgress)
        XCTAssertTrue(session.capturedImagePaths.isEmpty)
    }

    func test_execute_forMissingRoom_throws() async throws {
        do {
            _ = try await useCase.execute(roomID: UUID())
            XCTFail("Expected an error for a room that doesn't exist")
        } catch {
            // expected
        }
    }
}
