//
//  DomainValidationTests.swift
//  LastPlaceTests
//
//  Exercises the `validated()` extensions on the domain entities directly,
//  independent of any use case that happens to call them -- these are the
//  rules every creation/edit path relies on, so they're worth pinning down
//  on their own.
//

import XCTest
@testable import LastPlace

final class DomainValidationTests: XCTestCase {
    // MARK: Home

    func test_home_validated_trimsWhitespace() throws {
        let home = Home(name: "  My House  ")
        let validated = try home.validated()
        XCTAssertEqual(validated.name, "My House")
    }

    func test_home_validated_rejectsEmptyName() {
        let home = Home(name: "   ")
        XCTAssertThrowsError(try home.validated()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(field: "home"))
        }
    }

    func test_home_validated_rejectsNameOverLimit() {
        let home = Home(name: String(repeating: "a", count: Home.nameMaxLength + 1))
        XCTAssertThrowsError(try home.validated()) { error in
            XCTAssertEqual(error as? ValidationError, .nameTooLong(field: "home", limit: Home.nameMaxLength))
        }
    }

    // MARK: Room

    func test_room_validated_trimsWhitespace() throws {
        let room = Room(homeID: UUID(), name: "  Kitchen  ")
        let validated = try room.validated()
        XCTAssertEqual(validated.name, "Kitchen")
    }

    func test_room_validated_rejectsEmptyName() {
        let room = Room(homeID: UUID(), name: "")
        XCTAssertThrowsError(try room.validated()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(field: "room"))
        }
    }

    // MARK: Checklist / ChecklistEntry

    func test_checklist_validated_rejectsNameOverLimit() {
        let checklist = Checklist(name: String(repeating: "a", count: Checklist.nameMaxLength + 1), type: .work)
        XCTAssertThrowsError(try checklist.validated())
    }

    func test_checklistEntry_validated_rejectsEmptyTitle() {
        let entry = ChecklistEntry(checklistID: UUID(), title: "  ")
        XCTAssertThrowsError(try entry.validated()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(field: "checklist entry"))
        }
    }

    func test_checklistEntry_validated_rejectsLocationOverLimit() {
        let entry = ChecklistEntry(
            checklistID: UUID(),
            title: "Charger",
            locationDescription: String(repeating: "a", count: ChecklistEntry.locationMaxLength + 1)
        )
        XCTAssertThrowsError(try entry.validated()) { error in
            XCTAssertEqual(
                error as? ValidationError,
                .tooLong(field: "location", limit: ChecklistEntry.locationMaxLength)
            )
        }
    }

    func test_checklistEntry_validated_dropsEmptyTrimmedLocation() throws {
        let entry = ChecklistEntry(checklistID: UUID(), title: "Charger", locationDescription: "   ")
        let validated = try entry.validated()
        XCTAssertNil(validated.locationDescription)
    }

    // MARK: StoredItem

    func test_storedItem_validated_trimsNameAndLocation() throws {
        let item = StoredItem(roomID: UUID(), name: "  Keys  ", category: .keys, locationDescription: "  Hook  ")
        let validated = try item.validated()
        XCTAssertEqual(validated.name, "Keys")
        XCTAssertEqual(validated.locationDescription, "Hook")
    }

    func test_storedItem_validated_rejectsEmptyName() {
        let item = StoredItem(roomID: UUID(), name: "   ", category: .other, locationDescription: "Somewhere")
        XCTAssertThrowsError(try item.validated()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(field: "item"))
        }
    }

    func test_storedItem_validated_rejectsNotesOverLimit() {
        let item = StoredItem(
            roomID: UUID(),
            name: "Keys",
            category: .keys,
            notes: String(repeating: "a", count: StoredItem.notesMaxLength + 1),
            locationDescription: "Hook"
        )
        XCTAssertThrowsError(try item.validated()) { error in
            XCTAssertEqual(
                error as? ValidationError,
                .tooLong(field: "notes", limit: StoredItem.notesMaxLength)
            )
        }
    }

    func test_storedItem_validated_rejectsLocationOverLimit() {
        let item = StoredItem(
            roomID: UUID(),
            name: "Keys",
            category: .keys,
            locationDescription: String(repeating: "a", count: StoredItem.locationMaxLength + 1)
        )
        XCTAssertThrowsError(try item.validated()) { error in
            XCTAssertEqual(
                error as? ValidationError,
                .tooLong(field: "location", limit: StoredItem.locationMaxLength)
            )
        }
    }
}
