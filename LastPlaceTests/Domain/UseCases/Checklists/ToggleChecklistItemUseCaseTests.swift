//
//  ToggleChecklistItemUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class ToggleChecklistItemUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: ToggleChecklistItemUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultToggleChecklistItemUseCase(checklistRepository: repository)
    }

    func test_execute_flipsCompletionTwice() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        let entry = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Passport"))
        XCTAssertFalse(entry.isCompleted)

        let toggled = try await useCase.execute(entryID: entry.id)
        XCTAssertTrue(toggled.isCompleted)

        let toggledBack = try await useCase.execute(entryID: entry.id)
        XCTAssertFalse(toggledBack.isCompleted)
    }
}
