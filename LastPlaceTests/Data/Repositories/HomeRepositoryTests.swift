//
//  HomeRepositoryTests.swift
//  LastPlaceTests
//
//  `rename` and `delete` have no dedicated use case of their own, so this
//  is the only place they're exercised.
//

import XCTest
@testable import LastPlace

final class HomeRepositoryTests: XCTestCase {
    private var homeRepository: HomeRepository!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        homeRepository = SwiftDataHomeRepository(modelContainer: container)
    }

    func test_rename_updatesStoredName() async throws {
        let home = try await homeRepository.create(name: "Old Name")

        let renamed = try await homeRepository.rename(homeID: home.id, to: "New Name")

        XCTAssertEqual(renamed.id, home.id)
        XCTAssertEqual(renamed.name, "New Name")

        let all = try await homeRepository.fetchHomes()
        XCTAssertEqual(all.first(where: { $0.id == home.id })?.name, "New Name")
    }

    func test_delete_removesHome() async throws {
        let home = try await homeRepository.create(name: "Temporary")

        try await homeRepository.delete(homeID: home.id)

        let all = try await homeRepository.fetchHomes()
        XCTAssertFalse(all.contains(where: { $0.id == home.id }))
    }

    func test_rename_onMissingHome_throws() async throws {
        do {
            _ = try await homeRepository.rename(homeID: UUID(), to: "New Name")
            XCTFail("Expected an error for a home that doesn't exist")
        } catch {
            // expected
        }
    }
}
