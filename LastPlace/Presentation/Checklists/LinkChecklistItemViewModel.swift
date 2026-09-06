//
//  LinkChecklistItemViewModel.swift
//  LastPlace
//
//  Backs the "Add item" screen reachable from a checklist's detail view.
//  Reuses `SearchItemsUseCase` (same as the Search tab) to browse saved
//  items — blank query shows recent + important items, typed queries filter
//  — and adds entries via `AddChecklistEntryUseCase`, either linked to a
//  picked `StoredItem` or as a free-text title.
//

import Foundation
import Observation

@Observable
@MainActor
final class LinkChecklistItemViewModel {
    let checklistID: UUID
    var query: String = ""
    var customTitle: String = ""
    /// Optional — the whole point of a custom entry is to be fast to add, so
    /// this isn't required. See `canAddCustom`.
    var customLocation: String = ""
    private(set) var state: LoadableState<SearchResults> = .idle
    private(set) var linkedItemIDs: Set<UUID>
    private(set) var isAdding: Bool = false
    var error: UserFacingError?

    private let searchItemsUseCase: SearchItemsUseCase
    private let addEntryUseCase: AddChecklistEntryUseCase
    private let logger: AppLogger
    private var nextSortOrder: Int

    /// How long to wait after the last keystroke before searching — see
    /// `SearchViewModel` for the same pattern and rationale.
    private let debounceNanoseconds: UInt64 = 200_000_000

    init(
        checklistID: UUID,
        startingSortOrder: Int,
        alreadyLinkedItemIDs: Set<UUID>,
        searchItems: SearchItemsUseCase,
        addEntry: AddChecklistEntryUseCase,
        logger: AppLogger
    ) {
        self.checklistID = checklistID
        self.nextSortOrder = startingSortOrder
        self.linkedItemIDs = alreadyLinkedItemIDs
        self.searchItemsUseCase = searchItems
        self.addEntryUseCase = addEntry
        self.logger = logger
    }

    var canAddCustom: Bool {
        !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAdding
    }

    func load() async {
        guard case .idle = state else { return }
        await performSearch(query: query)
    }

    /// Called from `.task(id: viewModel.query)`; relies on SwiftUI cancelling
    /// the previous task on id-change for the debounce, same as `SearchViewModel`.
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }
        await performSearch(query: query)
    }

    func isLinked(_ itemID: UUID) -> Bool {
        linkedItemIDs.contains(itemID)
    }

    func addLinked(item: StoredItem) async {
        guard !isLinked(item.id), !isAdding else { return }
        isAdding = true
        defer { isAdding = false }
        do {
            _ = try await addEntryUseCase.execute(
                AddChecklistEntryInput(
                    checklistID: checklistID,
                    title: item.name,
                    linkedItemID: item.id,
                    sortOrder: nextSortOrder
                )
            )
            nextSortOrder += 1
            linkedItemIDs.insert(item.id)
        } catch {
            logger.error("Add linked checklist entry failed", error: error, category: "checklist-link-item")
            self.error = UserFacingError.from(error)
        }
    }

    func addCustom() async {
        guard canAddCustom else { return }
        isAdding = true
        defer { isAdding = false }
        let title = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await addEntryUseCase.execute(
                AddChecklistEntryInput(
                    checklistID: checklistID,
                    title: title,
                    linkedItemID: nil,
                    locationDescription: trimmedLocation.isEmpty ? nil : trimmedLocation,
                    sortOrder: nextSortOrder
                )
            )
            nextSortOrder += 1
            customTitle = ""
            customLocation = ""
        } catch {
            logger.error("Add custom checklist entry failed", error: error, category: "checklist-link-item")
            self.error = UserFacingError.from(error)
        }
    }

    private func performSearch(query: String) async {
        state = .loading
        do {
            let results = try await searchItemsUseCase.execute(query: query)
            state = results.isEmpty ? .empty : .loaded(results)
        } catch {
            logger.error("Link-item search failed", error: error, category: "checklist-link-item")
            state = .failed(UserFacingError.from(error))
        }
    }
}
