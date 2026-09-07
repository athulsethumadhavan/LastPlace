//
//  DeleteItemUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class DeleteItemUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: DeleteItemUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        useCase = DefaultDeleteItemUseCase(
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage
        )
    }

    func test_execute_removesItemSnapshotsAndImages() async throws {
        let itemImagePath = try await imageStorage.saveImageData(Data([0x01]), identifier: "item")
        let item = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Keys", category: .keys, imagePath: itemImagePath, locationDescription: "Hook")
        )
        let snapshotImagePath = try await imageStorage.saveImageData(Data([0x02]), identifier: "snapshot")
        _ = try await snapshotRepository.create(
            ItemSnapshot(itemID: item.id, roomID: item.roomID, imagePath: snapshotImagePath, locationDescription: "Hook", source: .manual)
        )

        try await useCase.execute(itemID: item.id)

        do {
            _ = try await itemRepository.fetchItem(itemID: item.id)
            XCTFail("Item should no longer exist")
        } catch {
            // expected
        }

        let remainingSnapshots = try await snapshotRepository.fetchSnapshots(itemID: item.id)
        XCTAssertTrue(remainingSnapshots.isEmpty)

        let imagesStillExist = await [
            imageStorage.imageExists(at: itemImagePath),
            imageStorage.imageExists(at: snapshotImagePath)
        ]
        XCTAssertEqual(imagesStillExist, [false, false])
    }
}
