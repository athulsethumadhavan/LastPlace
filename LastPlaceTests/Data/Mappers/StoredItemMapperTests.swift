//
//  StoredItemMapperTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class StoredItemMapperTests: XCTestCase {
    func test_toDomain_toEntity_roundTrips() {
        let item = StoredItem(
            roomID: UUID(),
            name: "Passport",
            category: .documents,
            notes: "Renew soon",
            imagePath: "item.jpg",
            locationDescription: "Drawer",
            isImportant: true,
            originSharedBy: UUID()
        )
        let entity = StoredItemMapper.toEntity(item)

        XCTAssertEqual(entity.categoryRaw, "documents")
        XCTAssertEqual(entity.originSharedBy, item.originSharedBy)

        let roundTripped = StoredItemMapper.toDomain(entity)
        XCTAssertEqual(roundTripped, item)
    }

    func test_toDomain_withUnrecognizedCategoryRaw_fallsBackToOther() {
        let entity = StoredItemEntity(
            id: UUID(),
            roomID: UUID(),
            name: "Mystery",
            categoryRaw: "not-a-real-category",
            notes: nil,
            imagePath: nil,
            locationDescription: "Somewhere",
            lastSeenAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            isImportant: false
        )

        let item = StoredItemMapper.toDomain(entity)
        XCTAssertEqual(item.category, .other)
    }

    func test_apply_doesNotTouchOriginSharedBy() {
        let originalOwner = UUID()
        let item = StoredItem(roomID: UUID(), name: "Old", category: .other, locationDescription: "Here", originSharedBy: originalOwner)
        let entity = StoredItemMapper.toEntity(item)

        var edited = item
        edited.name = "New"
        edited.originSharedBy = UUID() // a caller mistakenly changing it
        StoredItemMapper.apply(edited, to: entity)

        XCTAssertEqual(entity.name, "New")
        XCTAssertEqual(entity.originSharedBy, originalOwner, "apply() must never reassign originSharedBy after creation")
    }
}
