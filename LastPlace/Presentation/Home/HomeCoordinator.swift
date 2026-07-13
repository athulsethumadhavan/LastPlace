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
        RoomDetailViewModel(
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

        case .itemDetail:
            FeaturePlaceholderView(
                title: "Item Detail",
                subtitle: "Item detail ships in a later phase.",
                symbolName: "shippingbox"
            )

        case .updateItemLocation:
            FeaturePlaceholderView(
                title: "Update Location",
                subtitle: "Location updates ship in a later phase.",
                symbolName: "mappin.and.ellipse"
            )

        case .scanRoom:
            FeaturePlaceholderView(
                title: "Scan Room",
                subtitle: "The guided scan flow ships in Phase 5.",
                symbolName: "camera.viewfinder"
            )
        }
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
