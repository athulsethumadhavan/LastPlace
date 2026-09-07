//
//  RoomMapperTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class RoomMapperTests: XCTestCase {
    func test_toDomain_toEntity_roundTrips() {
        let room = Room(homeID: UUID(), name: "Garage", iconName: "car", coverImagePath: "cover.jpg")
        let entity = RoomMapper.toEntity(room)

        XCTAssertEqual(entity.id, room.id)
        XCTAssertEqual(entity.homeID, room.homeID)
        XCTAssertEqual(entity.coverImagePath, "cover.jpg")

        let roundTripped = RoomMapper.toDomain(entity)
        XCTAssertEqual(roundTripped, room)
    }

    func test_apply_updatesEditableFields() {
        let room = Room(homeID: UUID(), name: "Old")
        let entity = RoomMapper.toEntity(room)

        var updated = room
        updated.name = "New"
        updated.iconName = "sofa"
        updated.coverImagePath = "new-cover.jpg"
        updated.updatedAt = Date()
        RoomMapper.apply(updated, to: entity)

        XCTAssertEqual(entity.name, "New")
        XCTAssertEqual(entity.iconName, "sofa")
        XCTAssertEqual(entity.coverImagePath, "new-cover.jpg")
    }
}
