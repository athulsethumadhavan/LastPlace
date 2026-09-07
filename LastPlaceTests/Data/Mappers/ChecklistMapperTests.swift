//
//  ChecklistMapperTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class ChecklistMapperTests: XCTestCase {
    func test_toDomain_toEntity_roundTripsStandardType() {
        let checklist = Checklist(name: "Trip", type: .travel)
        let entity = ChecklistMapper.toEntity(checklist)

        XCTAssertEqual(entity.id, checklist.id)
        XCTAssertEqual(entity.name, checklist.name)
        XCTAssertEqual(entity.typeKind, "travel")
        XCTAssertNil(entity.customLabel)

        let roundTripped = ChecklistMapper.toDomain(entity)
        XCTAssertEqual(roundTripped, checklist)
    }

    func test_toDomain_toEntity_roundTripsCustomType() {
        let checklist = Checklist(name: "Hobby", type: .custom("Woodworking"))
        let entity = ChecklistMapper.toEntity(checklist)

        XCTAssertEqual(entity.typeKind, "custom")
        XCTAssertEqual(entity.customLabel, "Woodworking")

        let roundTripped = ChecklistMapper.toDomain(entity)
        XCTAssertEqual(roundTripped.type, .custom("Woodworking"))
    }

    func test_toDomain_withUnrecognizedTypeKind_fallsBackToCustom() {
        let entity = ChecklistEntity(
            id: UUID(),
            name: "Mystery",
            typeKind: "not-a-real-kind",
            customLabel: "Whatever",
            createdAt: Date(),
            updatedAt: Date()
        )

        let checklist = ChecklistMapper.toDomain(entity)
        XCTAssertEqual(checklist.type, .custom("Whatever"))
    }

    func test_apply_updatesNameTypeAndTimestampInPlace() {
        let entity = ChecklistMapper.toEntity(Checklist(name: "Old", type: .work))
        let updated = Checklist(id: entity.id, name: "New", type: .gym, createdAt: entity.createdAt, updatedAt: Date())

        ChecklistMapper.apply(updated, to: entity)

        XCTAssertEqual(entity.name, "New")
        XCTAssertEqual(entity.typeKind, "gym")
        XCTAssertEqual(entity.updatedAt, updated.updatedAt)
    }

    func test_entryMapper_roundTrips() {
        let entry = ChecklistEntry(
            checklistID: UUID(),
            title: "Passport",
            linkedItemID: UUID(),
            isCompleted: true,
            sortOrder: 3
        )
        let entity = ChecklistEntryMapper.toEntity(entry)
        let roundTripped = ChecklistEntryMapper.toDomain(entity)

        XCTAssertEqual(roundTripped, entry)
    }

    func test_entryMapper_apply_updatesFieldsInPlace() {
        let entry = ChecklistEntry(checklistID: UUID(), title: "Old title", sortOrder: 0)
        let entity = ChecklistEntryMapper.toEntity(entry)

        var updated = entry
        updated.title = "New title"
        updated.isCompleted = true
        ChecklistEntryMapper.apply(updated, to: entity)

        XCTAssertEqual(entity.title, "New title")
        XCTAssertTrue(entity.isCompleted)
    }
}
