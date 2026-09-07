//
//  CompleteScanSessionUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class CompleteScanSessionUseCaseTests: XCTestCase {
    private var scanRepository: ScanRepository!
    private var useCase: CompleteScanSessionUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        scanRepository = SwiftDataScanRepository(modelContainer: container)
        useCase = DefaultCompleteScanSessionUseCase(scanRepository: scanRepository)
    }

    func test_execute_marksSessionCompleted() async throws {
        let session = try await scanRepository.startSession(roomID: UUID())

        let completed = try await useCase.execute(sessionID: session.id)

        XCTAssertEqual(completed.status, .completed)
        XCTAssertNotNil(completed.completedAt)
    }
}
