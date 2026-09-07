//
//  ScanSessionMapperTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class ScanSessionMapperTests: XCTestCase {
    func test_toDomain_toEntity_roundTrips() {
        let session = ScanSession(
            roomID: UUID(),
            capturedImagePaths: ["a.jpg", "b.jpg"],
            status: .completed
        )
        let entity = ScanSessionMapper.toEntity(session)

        XCTAssertEqual(entity.statusRaw, "completed")
        XCTAssertEqual(entity.capturedImagePaths, ["a.jpg", "b.jpg"])

        let roundTripped = ScanSessionMapper.toDomain(entity)
        XCTAssertEqual(roundTripped, session)
    }

    func test_toDomain_withUnrecognizedStatusRaw_fallsBackToInProgress() {
        let entity = ScanSessionEntity(
            id: UUID(),
            roomID: UUID(),
            startedAt: Date(),
            completedAt: nil,
            capturedImagePaths: [],
            statusRaw: "not-a-real-status"
        )

        let session = ScanSessionMapper.toDomain(entity)
        XCTAssertEqual(session.status, .inProgress)
    }

    func test_apply_updatesStatusAndImages() {
        let session = ScanSession(roomID: UUID())
        let entity = ScanSessionMapper.toEntity(session)

        var updated = session
        updated.status = .cancelled
        updated.capturedImagePaths = ["x.jpg"]
        ScanSessionMapper.apply(updated, to: entity)

        XCTAssertEqual(entity.statusRaw, "cancelled")
        XCTAssertEqual(entity.capturedImagePaths, ["x.jpg"])
    }
}
