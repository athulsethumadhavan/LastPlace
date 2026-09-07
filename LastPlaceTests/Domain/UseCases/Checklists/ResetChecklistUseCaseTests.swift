//
//  ResetChecklistUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class ResetChecklistUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: ResetChecklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultResetChecklistUseCase(checklistRepository: repository)
    }

    func test_execute_marksEveryEntryIncomplete() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        let first = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Passport"))
        let second = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Charger"))
        _ = try await checklistRepository.toggle(entryID: first.id)
        _ = try await checklistRepository.toggle(entryID: second.id)

        try await useCase.execute(id: checklist.id)

        let entries = try await checklistRepository.fetchEntries(checklistID: checklist.id)
        XCTAssertTrue(entries.allSatisfy { !$0.isCompleted })
    }
}
