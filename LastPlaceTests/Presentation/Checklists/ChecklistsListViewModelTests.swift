//
//  ChecklistsListViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class ChecklistsListViewModelTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var viewModel: ChecklistsListViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        viewModel = ChecklistsListViewModel(
            fetchChecklists: DefaultFetchChecklistsUseCase(checklistRepository: checklistRepository),
            deleteChecklist: DefaultDeleteChecklistUseCase(checklistRepository: checklistRepository),
            checklistRepository: checklistRepository,
            logger: OSAppLogger()
        )
    }

    func test_load_withNoChecklists_isEmpty() async {
        await viewModel.load()
        guard case .empty = viewModel.state else {
            return XCTFail("Expected .empty state")
        }
    }

    func test_load_computesProgressPerChecklist() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        let entry = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Passport"))
        _ = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklist.id, title: "Charger"))
        _ = try await checklistRepository.toggle(entryID: entry.id)

        await viewModel.load()

        let progress = try XCTUnwrap(viewModel.progressByChecklistID[checklist.id])
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.total, 2)
    }

    func test_deleteChecklist_removesItAndReloads() async throws {
        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        await viewModel.load()

        await viewModel.deleteChecklist(id: checklist.id)

        guard case .empty = viewModel.state else {
            return XCTFail("Expected .empty state after deleting the only checklist")
        }
    }
}
