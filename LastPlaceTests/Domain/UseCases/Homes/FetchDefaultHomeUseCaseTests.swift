//
//  FetchDefaultHomeUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class FetchDefaultHomeUseCaseTests: XCTestCase {
    private var homeRepository: HomeRepository!
    private var useCase: FetchDefaultHomeUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataHomeRepository(modelContainer: container)
        homeRepository = repository
        useCase = DefaultFetchDefaultHomeUseCase(homeRepository: repository)
    }

    func test_execute_onFirstLaunch_createsAHome() async throws {
        let home = try await useCase.execute()
        XCTAssertFalse(home.name.isEmpty)
    }

    func test_execute_isIdempotent_returnsSameHomeOnSecondCall() async throws {
        let first = try await useCase.execute()
        let second = try await useCase.execute()
        XCTAssertEqual(first.id, second.id)

        let all = try await homeRepository.fetchHomes()
        XCTAssertEqual(all.count, 1)
    }
}
