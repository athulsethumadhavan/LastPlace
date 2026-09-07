//
//  CancelScanSessionUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class CancelScanSessionUseCaseTests: XCTestCase {
    private var scanRepository: ScanRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: CancelScanSessionUseCase!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        scanRepository = SwiftDataScanRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        useCase = DefaultCancelScanSessionUseCase(scanRepository: scanRepository, imageStorage: imageStorage)
    }

    func test_execute_marksSessionCancelledAndRemovesImages() async throws {
        let session = try await scanRepository.startSession(roomID: UUID())
        let path = try await imageStorage.saveImageData(Data([0x01]), identifier: "scan")
        _ = try await scanRepository.appendImage(sessionID: session.id, imagePath: path)

        try await useCase.execute(sessionID: session.id)

        let fetched = try await scanRepository.fetchSession(id: session.id)
        XCTAssertEqual(fetched.status, .cancelled)

        let stillExists = await imageStorage.imageExists(at: path)
        XCTAssertFalse(stillExists)
    }
}
