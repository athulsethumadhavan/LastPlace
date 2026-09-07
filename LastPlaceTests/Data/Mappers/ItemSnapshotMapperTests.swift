//
//  ItemSnapshotMapperTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class ItemSnapshotMapperTests: XCTestCase {
    func test_toDomain_toEntity_roundTrips() {
        let snapshot = ItemSnapshot(
            itemID: UUID(),
            roomID: UUID(),
            imagePath: "snap.jpg",
            locationDescription: "Drawer",
            confidence: 0.75,
            source: .scan
        )
        let entity = ItemSnapshotMapper.toEntity(snapshot)

        XCTAssertEqual(entity.sourceRaw, "scan")

        let roundTripped = ItemSnapshotMapper.toDomain(entity)
        XCTAssertEqual(roundTripped, snapshot)
    }

    func test_toDomain_withUnrecognizedSourceRaw_fallsBackToManual() {
        let entity = ItemSnapshotEntity(
            id: UUID(),
            itemID: UUID(),
            roomID: UUID(),
            imagePath: nil,
            locationDescription: "Somewhere",
            capturedAt: Date(),
            confidence: 0,
            sourceRaw: "not-a-real-source"
        )

        let snapshot = ItemSnapshotMapper.toDomain(entity)
        XCTAssertEqual(snapshot.source, .manual)
    }

    func test_apply_updatesLocationAndConfidence() {
        let snapshot = ItemSnapshot(itemID: UUID(), roomID: UUID(), locationDescription: "Old", source: .manual)
        let entity = ItemSnapshotMapper.toEntity(snapshot)

        var updated = snapshot
        updated.locationDescription = "New"
        updated.confidence = 0.9
        ItemSnapshotMapper.apply(updated, to: entity)

        XCTAssertEqual(entity.locationDescription, "New")
        XCTAssertEqual(entity.confidence, 0.9)
    }
}
