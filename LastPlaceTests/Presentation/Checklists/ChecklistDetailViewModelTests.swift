//
//  ChecklistDetailViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class ChecklistDetailViewModelTests: XCTestCase {
    private var checklistRepository: ChecklistRepository!
    private var itemRepository: ItemRepository!
    private var analytics: MockAnalyticsService!
    private var viewModel: ChecklistDetailViewModel!
    private var checklistID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        let container = try SwiftDataContainerFactory.makeInMemoryContainer()
        checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        itemRepository = SwiftDataItemRepository(modelContainer: container)
        analytics = MockAnalyticsService()

        let checklist = try await checklistRepository.create(Checklist(name: "Trip", type: .travel))
        checklistID = checklist.id

        viewModel = ChecklistDetailViewModel(
            checklistID: checklistID,
            fetchDetail: DefaultFetchChecklistDetailUseCase(checklistRepository: checklistRepository),
            toggleEntry: DefaultToggleChecklistItemUseCase(checklistRepository: checklistRepository),
            deleteEntry: DefaultDeleteChecklistEntryUseCase(checklistRepository: checklistRepository),
            resetChecklist: DefaultResetChecklistUseCase(checklistRepository: checklistRepository),
            deleteChecklist: DefaultDeleteChecklistUseCase(checklistRepository: checklistRepository),
            itemRepository: itemRepository,
            analytics: analytics,
            logger: OSAppLogger()
        )
    }

    func test_load_resolvesLinkedItemLocation() async throws {
        let item = try await itemRepository.create(
            StoredItem(roomID: UUID(), name: "Charger", category: .chargers, locationDescription: "Drawer")
        )
        _ = try await checklistRepository.addEntry(
            ChecklistEntry(checklistID: checklistID, title: "Charger", linkedItemID: item.id)
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.linkedItems[item.id]?.name, "Charger")
    }

    func test_toggle_logsChecklistCompleted_onlyOnTransitionIntoFullyComplete() async throws {
        let entry = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklistID, title: "Passport"))
        await viewModel.load()

        await viewModel.toggle(entry.id)
        XCTAssertEqual(analytics.loggedEventNames(), ["checklist_completed"])

        // Un-ticking the only entry takes it out of "fully complete" -- no event.
        await viewModel.toggle(entry.id)
        XCTAssertEqual(analytics.loggedEventNames(), ["checklist_completed"])

        // Re-ticking crosses back into "fully complete" -- logs again, since
        // this is a genuinely new completion, not a re-fire of the first one.
        await viewModel.toggle(entry.id)
        XCTAssertEqual(analytics.loggedEventNames(), ["checklist_completed", "checklist_completed"])
    }

    func test_deleteEntry_removesItAndReloads() async throws {
        let entry = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklistID, title: "Passport"))
        await viewModel.load()

        await viewModel.deleteEntry(entry.id)

        XCTAssertEqual(viewModel.state.value?.entries.count, 0)
    }

    func test_resetChecklist_marksEntriesIncomplete() async throws {
        let entry = try await checklistRepository.addEntry(ChecklistEntry(checklistID: checklistID, title: "Passport"))
        _ = try await checklistRepository.toggle(entryID: entry.id)
        await viewModel.load()

        await viewModel.resetChecklist()

        XCTAssertEqual(viewModel.state.value?.entries.first?.isCompleted, false)
    }

    func test_deleteChecklist_returnsTrueOnSuccess() async {
        let didDelete = await viewModel.deleteChecklist()
        XCTAssertTrue(didDelete)
    }
}
