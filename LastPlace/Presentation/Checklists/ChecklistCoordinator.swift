//
//  ChecklistCoordinator.swift
//  LastPlace
//
//  Owns the Checklists tab's `NavigationPath` plus the two view models that
//  need to survive across pushes: the root list (so create/delete are
//  visible on return) and whichever checklist detail is currently on screen
//  (so the "Add item" flow, pushed on top of it, can trigger a reload).
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ChecklistCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    /// Single source of truth for the Checklists tab's root screen.
    @ObservationIgnored
    private(set) lazy var checklistsListViewModel: ChecklistsListViewModel = makeChecklistsListViewModel()

    /// Weak handle to the currently-visible checklist detail view model, so
    /// the "Add item" screen can reload it before the user pops back.
    @ObservationIgnored
    weak var activeChecklistDetailViewModel: ChecklistDetailViewModel?

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: ChecklistRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }
    func popLast() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Reloads the checklist list. Call after creating or deleting a
    /// checklist, since returning to the root via `popLast`/`popToRoot` does
    /// not by itself re-trigger a load.
    func refreshChecklists() {
        Task { await checklistsListViewModel.refresh() }
    }

    /// Reloads the currently-visible checklist detail, if any. Call after
    /// adding, toggling, or deleting an entry from a screen pushed on top of
    /// it (namely the "Add item" flow).
    func refreshActiveChecklistDetail() {
        guard let viewModel = activeChecklistDetailViewModel else { return }
        Task { await viewModel.load() }
    }

    // MARK: View-model factories

    private func makeChecklistsListViewModel() -> ChecklistsListViewModel {
        ChecklistsListViewModel(
            fetchChecklists: DefaultFetchChecklistsUseCase(checklistRepository: container.checklistRepository),
            deleteChecklist: DefaultDeleteChecklistUseCase(checklistRepository: container.checklistRepository),
            checklistRepository: container.checklistRepository,
            logger: container.logger
        )
    }

    private func makeCreateChecklistViewModel() -> CreateChecklistViewModel {
        CreateChecklistViewModel(
            createChecklist: DefaultCreateChecklistUseCase(checklistRepository: container.checklistRepository),
            logger: container.logger
        )
    }

    /// Reuses the currently-active detail view model when the requested
    /// checklist matches it, instead of always constructing a new one.
    /// SwiftUI can re-invoke `destination(for:)` for a route already resident
    /// in the path (e.g. when `path` mutates because "Add item" gets pushed
    /// on top of it) — without this guard, that re-invocation would build a
    /// throwaway `ChecklistDetailViewModel` and silently repoint
    /// `activeChecklistDetailViewModel` at it, even though the screen actually
    /// on screen is still bound to the original instance via its own
    /// `@State`. `refreshActiveChecklistDetail()` would then reload the
    /// wrong, invisible view model and the visible list would look stale.
    private func makeChecklistDetailViewModel(checklistID: UUID) -> ChecklistDetailViewModel {
        if let existing = activeChecklistDetailViewModel, existing.checklistID == checklistID {
            return existing
        }
        let viewModel = ChecklistDetailViewModel(
            checklistID: checklistID,
            fetchDetail: DefaultFetchChecklistDetailUseCase(checklistRepository: container.checklistRepository),
            toggleEntry: DefaultToggleChecklistItemUseCase(checklistRepository: container.checklistRepository),
            deleteEntry: DefaultDeleteChecklistEntryUseCase(checklistRepository: container.checklistRepository),
            resetChecklist: DefaultResetChecklistUseCase(checklistRepository: container.checklistRepository),
            deleteChecklist: DefaultDeleteChecklistUseCase(checklistRepository: container.checklistRepository),
            itemRepository: container.itemRepository,
            logger: container.logger
        )
        activeChecklistDetailViewModel = viewModel
        return viewModel
    }

    /// Derives the picker's starting state from whichever checklist detail is
    /// currently active, so items already linked show as "added" and new
    /// entries are appended after the existing ones. Falls back to an empty
    /// checklist if the detail hasn't loaded yet (e.g. deep link).
    private func makeLinkChecklistItemViewModel(checklistID: UUID) -> LinkChecklistItemViewModel {
        let activeDetail = activeChecklistDetailViewModel?.checklistID == checklistID
            ? activeChecklistDetailViewModel?.state.value
            : nil

        return LinkChecklistItemViewModel(
            checklistID: checklistID,
            startingSortOrder: activeDetail?.entries.count ?? 0,
            alreadyLinkedItemIDs: Set((activeDetail?.entries ?? []).compactMap(\.linkedItemID)),
            searchItems: DefaultSearchItemsUseCase(itemRepository: container.itemRepository),
            addEntry: DefaultAddChecklistEntryUseCase(checklistRepository: container.checklistRepository),
            logger: container.logger
        )
    }

    // MARK: Destinations

    @ViewBuilder
    func destination(for route: ChecklistRoute) -> some View {
        switch route {
        case .detail(let checklistID):
            ChecklistDetailView(
                coordinator: self,
                viewModel: makeChecklistDetailViewModel(checklistID: checklistID)
            )
        case .create:
            CreateChecklistView(
                coordinator: self,
                viewModel: makeCreateChecklistViewModel()
            )
        case .linkItem(let checklistID):
            LinkChecklistItemView(
                coordinator: self,
                viewModel: makeLinkChecklistItemViewModel(checklistID: checklistID)
            )
        }
    }
}
