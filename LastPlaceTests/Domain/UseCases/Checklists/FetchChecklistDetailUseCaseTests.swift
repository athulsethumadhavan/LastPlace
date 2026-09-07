//
//  FetchChecklistDetailUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchChecklistDetailUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: FetchChecklistDetailUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultFetchChecklistDetailUseCase(checklistRepository: repository)
    }

    func test_execute_combinesChecklistAndEntries() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        _ = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Passport"))
        let second = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Charger"))
        _ = try await checklistRepository.toggle(entryID: second.id)

        let detail = try await useCase.execute(id: checklist.id)

        XCTAssertEqual(detail.checklist.id, checklist.id)
        XCTAssertEqual(detail.totalCount, 2)
        XCTAssertEqual(detail.completedCount, 1)
        XCTAssertEqual(detail.progress, 0.5)
    }

    func test_execute_withNoEntries_hasZeroProgress() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Empty", type: .work))
        let detail = try await useCase.execute(id: checklist.id)
        XCTAssertEqual(detail.totalCount, 0)
        XCTAssertEqual(detail.progress, 0)
    }
}
