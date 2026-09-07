//
//  DeleteChecklistUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class DeleteChecklistUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: DeleteChecklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultDeleteChecklistUseCase(checklistRepository: repository)
    }

    func test_execute_removesChecklist() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))

        try await useCase.execute(id: checklist.id)

        let all = try await checklistRepository.fetchChecklists()
        XCTAssertTrue(all.isEmpty)
    }

    func test_execute_onMissingChecklist_throws() async throws {
        do {
            try await useCase.execute(id: UUID())
            XCTFail("Expected an error for a checklist that doesn't exist")
        } catch {
            // Repository is free to throw RepositoryError.notFound or a
            // persistence-layer error; either way this must not silently succeed.
        }
    }
}
