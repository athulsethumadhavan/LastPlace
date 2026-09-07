//
//  FetchChecklistsUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchChecklistsUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: FetchChecklistsUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultFetchChecklistsUseCase(checklistRepository: repository)
    }

    func test_execute_withNoChecklists_returnsEmpty() async throws {
        let result = try await useCase.execute()
        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_returnsAllCreatedChecklists() async throws {
        _ = try await checklistRepository.create(Checklist(name: "Work", type: .work))
        _ = try await checklistRepository.create(Checklist(name: "Gym", type: .gym))

        let result = try await useCase.execute()

        XCTAssertEqual(Set(result.map(\.name)), ["Work", "Gym"])
    }
}
