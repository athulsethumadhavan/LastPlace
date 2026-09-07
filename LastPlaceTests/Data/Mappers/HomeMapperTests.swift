//
//  HomeMapperTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class HomeMapperTests: XCTestCase {
    func test_toDomain_toEntity_roundTrips() {
        let home = Home(name: "Main House")
        let entity = HomeMapper.toEntity(home)

        XCTAssertEqual(entity.id, home.id)
        XCTAssertEqual(entity.name, home.name)

        let roundTripped = HomeMapper.toDomain(entity)
        XCTAssertEqual(roundTripped, home)
    }

    func test_apply_updatesNameAndTimestamp() {
        let home = Home(name: "Old Name")
        let entity = HomeMapper.toEntity(home)

        var renamed = home
        renamed.name = "New Name"
        renamed.updatedAt = Date()
        HomeMapper.apply(renamed, to: entity)

        XCTAssertEqual(entity.name, "New Name")
        XCTAssertEqual(entity.updatedAt, renamed.updatedAt)
    }
}
