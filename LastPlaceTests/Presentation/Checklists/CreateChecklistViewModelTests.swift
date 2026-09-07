//
//  CreateChecklistViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class CreateChecklistViewModelTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var viewModel: CreateChecklistViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        viewModel = CreateChecklistViewModel(
            createChecklist: DefaultCreateChecklistUseCase(checklistRepository: checklistRepository),
            logger: OSAppLogger()
        )
    }

    func test_resolvedType_usesPresetByDefault() {
        viewModel.selectedPreset = .gym
        XCTAssertEqual(viewModel.resolvedType, .gym)
    }

    func test_resolvedType_whenCustom_usesTrimmedCustomName() {
        viewModel.isCustomType = true
        viewModel.customTypeName = "  Outdoors  "
        XCTAssertEqual(viewModel.resolvedType.displayName, "Outdoors")
    }

    func test_canSave_whenCustomWithBlankName_isFalse() {
        viewModel.name = "Camping List"
        viewModel.isCustomType = true
        viewModel.customTypeName = "   "
        XCTAssertFalse(viewModel.canSave)
    }

    func test_canSave_requiresNonBlankName() {
        XCTAssertFalse(viewModel.canSave)
        viewModel.name = "Ski Trip"
        XCTAssertTrue(viewModel.canSave)
    }

    func test_save_createsChecklistWithResolvedType() async throws {
        viewModel.name = "Ski Trip"
        viewModel.selectedPreset = .travel

        let saved = await viewModel.save()
        let checklist = try XCTUnwrap(saved)

        XCTAssertEqual(checklist.name, "Ski Trip")
        XCTAssertEqual(checklist.type, .travel)

        let all = try await checklistRepository.fetchChecklists()
        XCTAssertEqual(all.map(\.id), [checklist.id])
    }

    func test_save_withBlankName_returnsNil() async {
        let saved = await viewModel.save()
        XCTAssertNil(saved)
    }
}
