//
//  UpdateRoomUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class UpdateRoomUseCaseTests: XCTestCase {
    private var roomRepository: RoomRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: UpdateRoomUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataRoomRepository(modelContainer: container)
        roomRepository = repository
        imageStorage = MockImageStorageService()
        useCase = DefaultUpdateRoomUseCase(roomRepository: repository, imageStorage: imageStorage)
    }

    func test_execute_renamesRoom() async throws {
        var room = try await roomRepository.create(Room(homeID: UUID(), name: "Old Name"))
        room.name = "  New Name  "

        let updated = try await useCase.execute(UpdateRoomInput(room: room))

        XCTAssertEqual(updated.name, "New Name")
    }

    func test_execute_withNewCoverImage_replacesOldOne() async throws {
        let oldPath = try await imageStorage.saveImageData(Data([0x01]), identifier: "old-cover")
        var room = try await roomRepository.create(
            Room(homeID: UUID(), name: "Garage", coverImagePath: oldPath)
        )

        let newImageData = Data([0x02])
        let updated = try await useCase.execute(
            UpdateRoomInput(room: room, newCoverImageData: newImageData)
        )

        let newPath = try XCTUnwrap(updated.coverImagePath)
        XCTAssertNotEqual(newPath, oldPath)
        let storedNewImage = try await imageStorage.loadImageData(from: newPath)
        XCTAssertEqual(storedNewImage, newImageData)

        let oldStillExists = await imageStorage.imageExists(at: oldPath)
        XCTAssertFalse(oldStillExists)
    }

    func test_execute_withEmptyName_throwsValidationError() async throws {
        var room = try await roomRepository.create(Room(homeID: UUID(), name: "Garage"))
        room.name = "   "

        do {
            _ = try await useCase.execute(UpdateRoomInput(room: room))
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName(field: "room"))
        }
    }
}
