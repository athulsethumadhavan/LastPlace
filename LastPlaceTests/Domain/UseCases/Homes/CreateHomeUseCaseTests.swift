//
//  CreateHomeUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class CreateHomeUseCaseTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var useCase: CreateHomeUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataHomeRepository(modelContainer: container)
        homeRepository = repository
        useCase = DefaultCreateHomeUseCase(homeRepository: repository)
    }

    func test_execute_createsTrimmedHome() async throws {
        let home = try await useCase.execute(name: "  My House  ")
        XCTAssertEqual(home.name, "My House")

        let all = try await homeRepository.fetchHomes()
        XCTAssertEqual(all.map(\.id), [home.id])
    }

    func test_execute_withEmptyName_throwsValidationError() async throws {
        do {
            _ = try await useCase.execute(name: "   ")
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName(field: "home"))
        }
    }

    func test_execute_withNameTooLong_throwsValidationError() async throws {
        let tooLong = String(repeating: "a", count: Home.nameMaxLength + 1)
        do {
            _ = try await useCase.execute(name: tooLong)
            XCTFail("Expected a validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .nameTooLong(field: "home", limit: Home.nameMaxLength))
        }
    }
}
