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

    func makeItemDetailViewModel(itemID: UUID) -> ItemDetailViewModel {
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

    /// Search doesn't own a persistent results view model yet (the SearchView
    /// itself is still a placeholder). We only need to refresh the item detail
    /// currently on screen so it reflects saves made in update-location.
    func refreshAfterItemMutation() {
        refreshItemDetail()
    }
}
