//
//  SaveItemUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class SaveItemUseCaseTests: XCTestCase {
    private var itemRepository: ItemRepository!
    private var snapshotRepository: SnapshotRepository!
    private var imageStorage: MockImageStorageService!
    private var entitlementService: MockEntitlementService!
    private var useCase: SaveItemUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        snapshotRepository = SwiftDataSnapshotRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        entitlementService = MockEntitlementService(status: .free)
        useCase = DefaultSaveItemUseCase(
            itemRepository: itemRepository,
            snapshotRepository: snapshotRepository,
            imageStorage: imageStorage,
            entitlementService: entitlementService
        )
    }

    private func makeInput(name: String = "Keys") -> SaveItemInput {
        SaveItemInput(roomID: UUID(), name: name, category: .keys, locationDescription: "Hook")
    }

    func test_execute_savesItemAndInitialSnapshot() async throws {
        let item = try await useCase.execute(makeInput())

        let snapshots = try await snapshotRepository.fetchSnapshots(itemID: item.id)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].locationDescription, item.locationDescription)
    }

    func test_execute_withImageData_persistsImage() async throws {
        let imageData = Data([0x09])
        var input = makeInput()
        input = SaveItemInput(
            roomID: input.roomID,
            name: input.name,
            category: input.category,
            locationDescription: input.locationDescription,
            imageData: imageData
        )

        let item = try await useCase.execute(input)

        let path = try XCTUnwrap(item.imagePath)
        let stored = try await imageStorage.loadImageData(from: path)
        XCTAssertEqual(stored, imageData)
    }

    func test_execute_onFreeTierUnderLimit_succeeds() async throws {
        entitlementService.currentStatus = EntitlementStatus(isPremium: false, remainingItemSlots: 1)
        _ = try await useCase.execute(makeInput())
    }

    func test_execute_onFreeTierAtLimit_throwsItemLimitReachedError() async throws {
        for index in 0..<EntitlementStatus.freeItemLimit {
            _ = try await useCase.execute(makeInput(name: "Item \(index)"))
        }

        do {
            _ = try await useCase.execute(makeInput(name: "One too many"))
            XCTFail("Expected ItemLimitReachedError")
        } catch let error as ItemLimitReachedError {
            XCTAssertEqual(error.limit, EntitlementStatus.freeItemLimit)
        }
    }

    func test_execute_onPremium_ignoresItemCount() async throws {
        entitlementService.currentStatus = .premium
        for index in 0...(EntitlementStatus.freeItemLimit) {
            _ = try await useCase.execute(makeInput(name: "Item \(index)"))
        }
        let count = try await itemRepository.countItems()
        XCTAssertEqual(count, EntitlementStatus.freeItemLimit + 1)
    }

    func test_execute_whenEntitlementLookupFails_degradesToFreeTierCheck() async throws {
        entitlementService.lookupError = EntitlementError.notAuthenticated
        for index in 0..<EntitlementStatus.freeItemLimit {
            _ = try await useCase.execute(makeInput(name: "Item \(index)"))
        }

        do {
            _ = try await useCase.execute(makeInput(name: "One too many"))
            XCTFail("A failed entitlement lookup should still enforce the free-tier limit")
        } catch is ItemLimitReachedError {
            // expected
        }
    }

    func test_execute_withEmptyName_throwsValidationError() async throws {
        do {
            _ = try await useCase.execute(makeInput(name: "   "))
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName(field: "item"))
        }
    }
}
