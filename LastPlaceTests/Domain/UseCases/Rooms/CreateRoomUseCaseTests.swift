//
//  CreateRoomUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class CreateRoomUseCaseTests: XCTestCase {
    private var roomRepository: RoomRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: CreateRoomUseCase!
    private var homeID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataRoomRepository(modelContainer: container)
        roomRepository = repository
        imageStorage = MockImageStorageService()
        useCase = DefaultCreateRoomUseCase(roomRepository: repository, imageStorage: imageStorage)
        homeID = UUID()
    }

    func test_execute_createsTrimmedRoom() async throws {
        let room = try await useCase.execute(CreateRoomInput(homeID: homeID, name: "  Kitchen  "))

        XCTAssertEqual(room.name, "Kitchen")
        XCTAssertEqual(room.homeID, homeID)
        XCTAssertNil(room.coverImagePath)

        let all = try await roomRepository.fetchRooms(homeID: homeID)
        XCTAssertEqual(all.map(\.id), [room.id])
    }

    func test_execute_withCoverImageData_persistsImageAndPath() async throws {
        let imageData = Data([0x01, 0x02, 0x03])
        let room = try await useCase.execute(CreateRoomInput(homeID: homeID, name: "Garage", coverImageData: imageData))

        let path = try XCTUnwrap(room.coverImagePath)
        let stored = try await imageStorage.loadImageData(from: path)
        XCTAssertEqual(stored, imageData)
    }

    func test_execute_withEmptyName_throwsValidationError() async throws {
        do {
            _ = try await useCase.execute(CreateRoomInput(homeID: homeID, name: "   "))
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName(field: "room"))
        }
    }
}
