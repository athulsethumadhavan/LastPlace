//
//  ChecklistDetailViewModel.swift
//  LastPlace
//
//  Loads a checklist's entries and resolves the `StoredItem` behind any
//  linked entry so the detail screen can show its current location without
//  the view reaching into the repository itself.
//

import Foundation
import Observation

@Observable
@MainActor
final class ChecklistDetailViewModel {
    let checklistID: UUID
    private(set) var state: LoadableState<ChecklistDetail> = .idle
    private(set) var linkedItems: [UUID: StoredItem] = [:]
    private(set) var isDeleting: Bool = false
    var mutationError: UserFacingError?

    private let fetchDetailUseCase: FetchChecklistDetailUseCase
    private let toggleEntryUseCase: ToggleChecklistItemUseCase
    private let deleteEntryUseCase: DeleteChecklistEntryUseCase
    private let resetChecklistUseCase: ResetChecklistUseCase
    private let deleteChecklistUseCase: DeleteChecklistUseCase
    private let itemRepository: ItemRepository
    private let logger: AppLogger

    init(
        checklistID: UUID,
        fetchDetail: FetchChecklistDetailUseCase,
        toggleEntry: ToggleChecklistItemUseCase,
        deleteEntry: DeleteChecklistEntryUseCase,
        resetChecklist: ResetChecklistUseCase,
        deleteChecklist: DeleteChecklistUseCase,
        itemRepository: ItemRepository,
        logger: AppLogger
    ) {
        self.checklistID = checklistID
        self.fetchDetailUseCase = fetchDetail
        self.toggleEntryUseCase = toggleEntry
        self.deleteEntryUseCase = deleteEntry
        self.resetChecklistUseCase = resetChecklist
        self.deleteChecklistUseCase = deleteChecklist
        self.itemRepository = itemRepository
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let detail = try await fetchDetailUseCase.execute(id: checklistID)
            state = .loaded(detail)
            await loadLinkedItems(for: detail.entries)
        } catch {
            logger.error("Checklist detail load failed", error: error, category: "checklist-detail")
            state = .failed(UserFacingError.from(error))
        }
    }

    func toggle(_ entryID: UUID) async {
        do {
            _ = try await toggleEntryUseCase.execute(entryID: entryID)
            await load()
        } catch {
            logger.error("Toggle checklist entry failed", error: error, category: "checklist-detail")
            mutationError = UserFacingError.from(error)
        }
    }

    func deleteEntry(_ entryID: UUID) async {
        do {
            try await deleteEntryUseCase.execute(entryID: entryID)
            await load()
        } catch {
            logger.error("Delete checklist entry failed", error: error, category: "checklist-detail")
            mutationError = UserFacingError.from(error)
        }
    }

    func resetChecklist() async {
        do {
            try await resetChecklistUseCase.execute(id: checklistID)
            await load()
        } catch {
            logger.error("Reset checklist failed", error: error, category: "checklist-detail")
            mutationError = UserFacingError.from(error)
        }
    }

    /// Returns `true` on success so the view can pop.
    func deleteChecklist() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await deleteChecklistUseCase.execute(id: checklistID)
            return true
        } catch {
            logger.error("Delete checklist failed", error: error, category: "checklist-detail")
            mutationError = UserFacingError.from(error)
            return false
        }
    }

    private func loadLinkedItems(for entries: [ChecklistEntry]) async {
        let ids = Set(entries.compactMap(\.linkedItemID))
        guard !ids.isEmpty else {
            linkedItems = [:]
            return
        }
        var result: [UUID: StoredItem] = [:]
        for id in ids {
            if let item = try? await itemRepository.fetchItem(itemID: id) {
                result[id] = item
            }
        }
        linkedItems = result
    }
}
