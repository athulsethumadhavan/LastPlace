//
//  DeleteChecklistEntryUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class DeleteChecklistEntryUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: DeleteChecklistEntryUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultDeleteChecklistEntryUseCase(checklistRepository: repository)
    }

    func test_execute_removesEntry() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        let entry = try await checklistRepository.addEntry(
            ChecklistEntry(checklistID: checklist.id, title: "Passport")
        )

        try await useCase.execute(entryID: entry.id)

        let remaining = try await checklistRepository.fetchEntries(checklistID: checklist.id)
        XCTAssertTrue(remaining.isEmpty)
    }
}
