//
//  HomeCoordinator.swift
//  LastPlace
//
//  Owns the Home tab's `NavigationPath`, vends view models constructed from
//  the shared `AppDependencyContainer`, and builds destination views for each
//  route. Room detail / create room ship in Phase 4; item detail, edit-room,
//  update-location and scan flow are placeholders until later phases.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class HomeCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    /// Single source of truth for the Home tab's root screen. Owned here (not
    /// by `HomeView`) so that any flow reachable from Home — create room,
    /// delete room, edit room, etc. — can ask the coordinator to refresh the
    /// dashboard after a mutation, even though those flows are pushed on top
    /// of `HomeView` and never re-run its `.task`.
    @ObservationIgnored
    private(set) lazy var homeViewModel: HomeViewModel = makeRootViewModel()

    /// Weak handle to the currently-visible room detail view model, so flows
    /// pushed above room detail (scan flow, edit room, etc.) can force it to
    /// reload after a mutation. Weak so it nils out when the user pops back
    /// past room detail.
    @ObservationIgnored
    weak var activeRoomDetailViewModel: RoomDetailViewModel?

    /// Same rationale as `activeRoomDetailViewModel` — lets flows pushed above
    /// item detail (update-location) force it to reload without a `.task`
    /// re-fire.
    @ObservationIgnored
    weak var activeItemDetailViewModel: ItemDetailViewModel?

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: HomeRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }
    func popLast() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Reloads the Home dashboard (rooms, recent items, important items).
    /// Call this after any mutation made from a screen pushed on top of Home
    /// — creating, deleting, or editing a room; moving or updating an item —
    /// since returning to Home via `popLast`/`popToRoot` does not by itself
    /// re-trigger a load.
    func refreshHome() {
        Task { await homeViewModel.refresh() }
    }

    /// Reloads the currently-visible RoomDetail screen, if any. No-op when
    /// room detail isn't in the stack. Same rationale as `refreshHome`: pops
    /// back to room detail don't re-run its `.task`.
    func refreshRoomDetail() {
        guard let viewModel = activeRoomDetailViewModel else { return }
        Task { await viewModel.load() }
    }

    /// Reloads the currently-visible ItemDetail screen, if any.
    func refreshItemDetail() {
        guard let viewModel = activeItemDetailViewModel else { return }
        Task { await viewModel.load() }
    }

    // MARK: View-model factories

    private func makeRootViewModel() -> HomeViewModel {
        HomeViewModel(
            fetchDefaultHome: DefaultFetchDefaultHomeUseCase(homeRepository: container.homeRepository),
            fetchRooms: DefaultFetchRoomsUseCase(roomRepository: container.roomRepository),
            fetchRecent: DefaultFetchRecentItemsUseCase(itemRepository: container.itemRepository),
            fetchImportant: DefaultFetchImportantItemsUseCase(itemRepository: container.itemRepository),
            configuration: container.configuration,
            logger: container.logger
        )
    }

    func makeRoomDetailViewModel(roomID: UUID) -> RoomDetailViewModel {
        let viewModel = RoomDetailViewModel(
            roomID: roomID,
            fetchRoom: DefaultFetchRoomUseCase(roomRepository: container.roomRepository),
            fetchItems: DefaultFetchItemsForRoomUseCase(itemRepository: container.itemRepository),
            deleteRoom: DefaultDeleteRoomUseCase(
                roomRepository: container.roomRepository,
                itemRepository: container.itemRepository,
                snapshotRepository: container.snapshotRepository,
                imageStorage: container.imageStorage
            ),
            logger: container.logger
        )
        activeRoomDetailViewModel = viewModel
        return viewModel
    }

    func makeCreateRoomViewModel(homeID: UUID) -> CreateRoomViewModel {
        CreateRoomViewModel(
            homeID: homeID,
            createRoom: DefaultCreateRoomUseCase(
                roomRepository: container.roomRepository,
                imageStorage: container.imageStorage
            ),
            logger: container.logger
        )
    }

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

    // MARK: Destinations

    @ViewBuilder
    func destination(for route: HomeRoute) -> some View {
        switch route {
        case .roomDetail(let roomID):
            RoomDetailView(
                coordinator: self,
                viewModel: makeRoomDetailViewModel(roomID: roomID)
            )

        case .createRoom:
            CreateRoomHost(coordinator: self)

        case .editRoom:
            FeaturePlaceholderView(
                title: "Edit Room",
                subtitle: "Editing room details ships in a later phase.",
                symbolName: "pencil"
            )

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

        case .scanRoom(let roomID):
            ScanRootView(
                homeCoordinator: self,
                coordinator: ScanCoordinator(roomID: roomID, container: container)
            )
        }
    }
}

extension HomeCoordinator: ItemDetailNavigator {
    func pushUpdateItemLocation(itemID: UUID) {
        push(.updateItemLocation(itemID: itemID))
    }

    func popTop() { popLast() }

    /// Item-flow mutations can affect the Home dashboard (recent + important
    /// lists), the Room Detail item grid, and the current item detail screen
    /// (when an update-location save returns).
    func refreshAfterItemMutation() {
        refreshItemDetail()
        refreshRoomDetail()
        refreshHome()
    }
}

/// Fetches the default home before showing the CreateRoom form, so the view
/// model doesn't have to juggle two async states. Home lookup rarely fails
/// (`HomeRepository.fetchDefaultHome()` creates one if missing), but we still
/// present an error state on failure.
private struct CreateRoomHost: View {
    let coordinator: HomeCoordinator

    @State private var homeID: UUID?
    @State private var error: UserFacingError?

    var body: some View {
        Group {
            if let homeID {
                CreateRoomView(
                    coordinator: coordinator,
                    viewModel: coordinator.makeCreateRoomViewModel(homeID: homeID)
                )
            } else if let error {
                ErrorStateView(error: error) { Task { await load() } }
            } else {
                LoadingView()
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let home = try await coordinator.container.homeRepository.fetchDefaultHome()
            homeID = home.id
            error = nil
        } catch {
            self.error = UserFacingError.from(error)
        }
    }
}
