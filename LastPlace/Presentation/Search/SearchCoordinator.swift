//
//  SearchCoordinator.swift
//  LastPlace
//

import SwiftUI
import Observation

@Observable
@MainActor
final class SearchCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    /// Weak handle to the currently-visible item detail view model, so an
    /// update-location save can reload it before the user pops back.
    @ObservationIgnored
    weak var activeItemDetailViewModel: ItemDetailViewModel?

    /// Single source of truth for the Search tab's root screen. Owned here
    /// (not by `SearchView`) for the same reason `HomeCoordinator` owns
    /// `homeViewModel`: item detail / update-location are pushed on top of
    /// Search and need a way to tell the results list to reload after a
    /// mutation, even though popping back doesn't by itself re-trigger one.
    @ObservationIgnored
    private(set) lazy var searchViewModel: SearchViewModel = makeSearchViewModel()

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: SearchRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }
    func popLast() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func refreshItemDetail() {
        guard let viewModel = activeItemDetailViewModel else { return }
        Task { await viewModel.load() }
    }

    // MARK: View-model factories

    private func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(
            searchItems: DefaultSearchItemsUseCase(itemRepository: container.itemRepository),
            logger: container.logger
        )
    }

    /// Reuses the currently-active item detail view model when the requested
    /// item matches it, instead of always constructing a new one — see the
    /// matching note in `HomeCoordinator.makeItemDetailViewModel` for why.
    func makeItemDetailViewModel(itemID: UUID) -> ItemDetailViewModel {
        if let existing = activeItemDetailViewModel, existing.itemID == itemID {
            return existing
        }
        let viewModel = ItemDetailViewModel(
            itemID: itemID,
            fetchDetail: DefaultFetchItemDetailUseCase(
                itemRepository: container.itemRepository,
                roomRepository: container.roomRepository,
                snapshotRepository: container.snapshotRepository
            ),
            deleteItem: DefaultDeleteItemUseCase(
                itemRepository: container.itemRepository,
                snapshotRepository: container.snapshotRepository,
                imageStorage: container.imageStorage
            ),
            toggleImportance: DefaultToggleItemImportanceUseCase(itemRepository: container.itemRepository),
            logger: container.logger
        )
        activeItemDetailViewModel = viewModel
        return viewModel
    }

    func makeUpdateItemLocationViewModel(itemID: UUID) -> UpdateItemLocationViewModel {
        UpdateItemLocationViewModel(
            itemID: itemID,
            fetchDetail: DefaultFetchItemDetailUseCase(
                itemRepository: container.itemRepository,
                roomRepository: container.roomRepository,
                snapshotRepository: container.snapshotRepository
            ),
            updateLocation: DefaultUpdateItemLocationUseCase(
                itemRepository: container.itemRepository,
                snapshotRepository: container.snapshotRepository,
                imageStorage: container.imageStorage
            ),
            logger: container.logger
        )
    }

    @ViewBuilder
    func destination(for route: SearchRoute) -> some View {
        switch route {
        case .itemDetail(let itemID):
            ItemDetailView(
                navigator: self,
                viewModel: makeItemDetailViewModel(itemID: itemID)
            )
        case .updateItemLocation(let itemID):
            UpdateItemLocationView(
                navigator: self,
                viewModel: makeUpdateItemLocationViewModel(itemID: itemID)
            )
        }
    }
}

extension SearchCoordinator: ItemDetailNavigator {
    func pushUpdateItemLocation(itemID: UUID) {
        push(.updateItemLocation(itemID: itemID))
    }

    func popTop() { popLast() }

    /// Refreshes both the item detail currently on screen (so it reflects
    /// saves made in update-location) and the Search results list underneath
    /// (so a delete, importance toggle, or location update is visible the
    /// moment the user pops back to it).
    func refreshAfterItemMutation() {
        refreshItemDetail()
        Task { await searchViewModel.refresh() }
    }
}
