//
//  UpdateItemLocationUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class UpdateItemLocationUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: UpdateItemLocationUseCase!
    private var itemID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        useCase = DefaultUpdateItemLocationUseCase(
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage
        )
        let item = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Keys", category: .keys, locationDescription: "Hook")
        )
        itemID = item.id
    }

    func test_execute_updatesLocationAndRecordsSnapshot() async throws {
        let updated = try await useCase.execute(
            UpdateItemLocationInput(itemID: itemID, description: "  Kitchen counter  ")
        )

        XCTAssertEqual(updated.locationDescription, "Kitchen counter")

        let snapshots = try await snapshotRepository.fetchSnapshots(itemID: itemID)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].locationDescription, "Kitchen counter")
    }

    func test_execute_withImageData_persistsImageOnBothItemAndSnapshot() async throws {
        let imageData = Data([0x05])
        _ = try await useCase.execute(
            UpdateItemLocationInput(itemID: itemID, description: "Shelf", imageData: imageData)
        )

        let snapshots = try await snapshotRepository.fetchSnapshots(itemID: itemID)
        let path = try XCTUnwrap(snapshots.first?.imagePath)
        let stored = try await imageStorage.loadImageData(from: path)
        XCTAssertEqual(stored, imageData)
    }

    func test_execute_withDescriptionTooLong_throwsValidationError() async throws {
        let tooLong = String(repeating: "a", count: StoredItem.locationMaxLength + 1)
        do {
            _ = try await useCase.execute(UpdateItemLocationInput(itemID: itemID, description: tooLong))
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .tooLong(field: "location", limit: StoredItem.locationMaxLength))
        }
    }
}
