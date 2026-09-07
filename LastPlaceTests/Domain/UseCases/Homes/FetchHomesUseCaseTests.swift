//
//  FetchHomesUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchHomesUseCaseTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var useCase: FetchHomesUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataHomeRepository(modelContainer: container)
        homeRepository = repository
        useCase = DefaultFetchHomesUseCase(homeRepository: repository)
    }

    func test_execute_withNoHomes_returnsEmpty() async throws {
        let result = try await useCase.execute()
        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_returnsCreatedHomes() async throws {
        _ = try await homeRepository.create(name: "Main House")
        _ = try await homeRepository.create(name: "Cabin")

        let result = try await useCase.execute()
        XCTAssertEqual(Set(result.map(\.name)), ["Main House", "Cabin"])
    }
}
