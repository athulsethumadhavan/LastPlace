//
//  AppendScanImageUseCaseTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

final class AppendScanImageUseCaseTests: XCTestCase {
    private var scanRepository: ScanRepository!
    private var imageStorage: MockImageStorageService!
    private var useCase: AppendScanImageUseCase!
    private var sessionID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        scanRepository = SwiftDataScanRepository(modelContainer: container)
        imageStorage = MockImageStorageService()
        useCase = DefaultAppendScanImageUseCase(scanRepository: scanRepository, imageStorage: imageStorage)
        let session = try await scanRepository.startSession(roomID: UUID())
        sessionID = session.id
    }

    func test_execute_savesImageAndAppendsPath() async throws {
        let imageData = Data([0x01, 0x02])
        let session = try await useCase.execute(sessionID: sessionID, imageData: imageData)

        XCTAssertEqual(session.capturedImagePaths.count, 1)
        let path = try XCTUnwrap(session.capturedImagePaths.first)
        let stored = try await imageStorage.loadImageData(from: path)
        XCTAssertEqual(stored, imageData)
    }

    func test_execute_calledTwice_appendsBothImages() async throws {
        _ = try await useCase.execute(sessionID: sessionID, imageData: Data([0x01]))
        let session = try await useCase.execute(sessionID: sessionID, imageData: Data([0x02]))

        XCTAssertEqual(session.capturedImagePaths.count, 2)
    }
}
