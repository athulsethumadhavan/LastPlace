//
//  CreateChecklistUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class CreateChecklistUseCaseTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var useCase: CreateChecklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataChecklistRepository(modelContainer: container)
        checklistRepository = repository
        useCase = DefaultCreateChecklistUseCase(checklistRepository: repository)
    }

    func test_execute_createsTrimmedChecklist() async throws {
        let checklist = try await useCase.execute(name: "  Ski Trip  ", type: .travel)

        XCTAssertEqual(checklist.name, "Ski Trip")
        XCTAssertEqual(checklist.type, .travel)

        let all = try await checklistRepository.fetchChecklists()
        XCTAssertEqual(all.map(\.id), [checklist.id])
    }

    func test_execute_withCustomType_preservesLabel() async throws {
        let checklist = try await useCase.execute(name: "Camping", type: .custom("Outdoors"))
        XCTAssertEqual(checklist.type.displayName, "Outdoors")
    }

    func test_execute_withEmptyName_throwsValidationError() async throws {
        do {
            _ = try await useCase.execute(name: "   ", type: .work)
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName(field: "checklist"))
        }
    }

    func test_execute_withNameTooLong_throwsValidationError() async throws {
        let tooLong = String(repeating: "a", count: Checklist.nameMaxLength + 1)
        do {
            _ = try await useCase.execute(name: tooLong, type: .work)
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .nameTooLong(field: "checklist", limit: Checklist.nameMaxLength))
        }
    }
}
