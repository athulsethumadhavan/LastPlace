//
//  AddChecklistEntryUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class AddChecklistEntryUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: AddChecklistEntryUseCase!
    private var checklistID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultAddChecklistEntryUseCase(checklistRepository: repository)
        let checklist = try await repository.create(Checklist(name: "Packing", type: .travel))
        checklistID = checklist.id
    }

    func test_execute_addsTrimmedEntryToChecklist() async throws {
        let entry = try await useCase.execute(AddChecklistEntryInput(
            checklistID: checklistID,
            title: "  Passport  "
        ))

        XCTAssertEqual(entry.title, "Passport")
        XCTAssertEqual(entry.checklistID, checklistID)
        XCTAssertFalse(entry.isCompleted)

        let stored = try await checklistRepository.fetchEntries(checklistID: checklistID)
        XCTAssertEqual(stored.map(\.id), [entry.id])
    }

    func test_execute_withEmptyTitle_throwsValidationError() async throws {
        do {
            _ = try await useCase.execute(AddChecklistEntryInput(checklistID: checklistID, title: "   "))
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName(field: "checklist entry"))
        }
    }

    func test_execute_withTitleTooLong_throwsValidationError() async throws {
        let tooLong = String(repeating: "a", count: ChecklistEntry.titleMaxLength + 1)
        do {
            _ = try await useCase.execute(AddChecklistEntryInput(checklistID: checklistID, title: tooLong))
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .nameTooLong(field: "checklist entry", limit: ChecklistEntry.titleMaxLength))
        }
    }

    func test_execute_withLinkedItem_ignoresLocationDescription() async throws {
        let itemID = UUID()
        let entry = try await useCase.execute(AddChecklistEntryInput(
            checklistID: checklistID,
            title: "Charger",
            linkedItemID: itemID,
            locationDescription: "Top drawer"
        ))

        XCTAssertEqual(entry.linkedItemID, itemID)
        XCTAssertNil(entry.locationDescription)
    }

    func test_execute_withoutLinkedItem_keepsLocationDescription() async throws {
        let entry = try await useCase.execute(AddChecklistEntryInput(
            checklistID: checklistID,
            title: "Charger",
            locationDescription: "  Top drawer  "
        ))

        XCTAssertEqual(entry.locationDescription, "Top drawer")
    }
}
