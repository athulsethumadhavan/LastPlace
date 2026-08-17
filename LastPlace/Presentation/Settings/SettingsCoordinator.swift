//
//  SettingsCoordinator.swift
//  LastPlace
//

import SwiftUI
import Observation

@Observable
@MainActor
final class SettingsCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    /// Set by `MainTabView` when the tab coordinators are assembled, so a
    /// "Delete All Data" here can tell the sibling tabs (Home, Search,
    /// Checklists) to reload. `SettingsCoordinator` doesn't hold references
    /// to those coordinators directly — this closure keeps it decoupled from
    /// their concrete types.
    @ObservationIgnored
    var onAllDataDeleted: (() -> Void)?

    /// Set by `MainTabView`, so accepting a gift here (Settings > Gifts)
    /// tells Home to reload -- otherwise the newly-created item wouldn't
    /// appear there until the next full refresh/relaunch, even though it
    /// was written to local storage immediately (see
    /// `GiftsViewModel.accept`'s doc comment). Same rationale and shape as
    /// `onAllDataDeleted`.
    @ObservationIgnored
    var onGiftAccepted: (() -> Void)?

    /// Set by `MainTabView` (via `RootView`/`AppCoordinator`) so a sign-out
    /// or account deletion in Settings' account section can send the whole app back
    /// through the `.authRequired` gate, not just pop this tab's own
    /// navigation stack.
    @ObservationIgnored
    var onSignedOut: (() -> Void)?

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: SettingsRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }

    func notifyAllDataDeleted() {
        onAllDataDeleted?()
    }

    func notifyGiftAccepted() {
        onGiftAccepted?()
    }

    // MARK: View-model factories

    /// Not private: `SettingsView` renders appearance and account inline
    /// rather than pushing screens for them, so it builds these itself.
    func makeAppearanceViewModel() -> AppearanceViewModel {
        AppearanceViewModel(store: container.appearanceSettings)
    }

    func makeAccountViewModel() -> AccountViewModel {
        AccountViewModel(
            authService: container.authService,
            deviceTokenService: container.deviceTokenService,
            onSignedOut: { [weak self] in self?.onSignedOut?() }
        )
    }

    private func makeSecurityViewModel() -> SecurityViewModel {
        SecurityViewModel(
            store: container.appLockSettings,
            biometricAuthenticator: container.biometricAuthenticator
        )
    }

    private func makeDataManagementViewModel() -> DataManagementViewModel {
        DataManagementViewModel(
            fetchSummary: DefaultFetchDataSummaryUseCase(
                homeRepository: container.homeRepository,
                roomRepository: container.roomRepository,
                itemRepository: container.itemRepository,
                checklistRepository: container.checklistRepository
            ),
            deleteAllData: DefaultDeleteAllDataUseCase(
                homeRepository: container.homeRepository,
                roomRepository: container.roomRepository,
                checklistRepository: container.checklistRepository,
                deleteRoom: DefaultDeleteRoomUseCase(
                    roomRepository: container.roomRepository,
                    itemRepository: container.itemRepository,
                    snapshotRepository: container.snapshotRepository,
                    imageStorage: container.imageStorage
                ),
                deleteChecklist: DefaultDeleteChecklistUseCase(checklistRepository: container.checklistRepository)
            ),
            logger: container.logger
        )
    }

    private func makeSharedRoomsViewModel() -> SharedRoomsViewModel {
        SharedRoomsViewModel(roomSharingService: container.roomSharingService, logger: container.logger)
    }

    private func makeSharedRoomDetailViewModel(roomID: UUID, ownerID: UUID) -> SharedRoomDetailViewModel {
        SharedRoomDetailViewModel(
            roomID: roomID,
            ownerID: ownerID,
            roomSharingService: container.roomSharingService,
            logger: container.logger
        )
    }

    private func makeSharedItemDetailViewModel(
        itemID: UUID,
        roomID: UUID,
        ownerID: UUID
    ) -> SharedItemDetailViewModel {
        SharedItemDetailViewModel(
            itemID: itemID,
            roomID: roomID,
            ownerID: ownerID,
            roomSharingService: container.roomSharingService,
            authService: container.authService,
            logger: container.logger
        )
    }

    private func makeGiftsViewModel() -> GiftsViewModel {
        GiftsViewModel(
            itemGiftingService: container.itemGiftingService,
            homeRepository: container.homeRepository,
            roomRepository: container.roomRepository,
            itemRepository: container.itemRepository,
            imageStorage: container.imageStorage,
            syncEngine: container.syncEngine,
            authService: container.authService,
            analytics: container.analytics,
            logger: container.logger,
            onAccepted: { [weak self] in self?.notifyGiftAccepted() }
        )
    }

    // MARK: Destinations

    @ViewBuilder
    func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .privacy:
            PrivacyView()
        case .permissions:
            PermissionsView()
        case .security:
            SecurityView(viewModel: makeSecurityViewModel())
        case .dataManagement:
            DataManagementView(coordinator: self, viewModel: makeDataManagementViewModel())
        case .sharedRooms:
            SharedRoomsView(coordinator: self, viewModel: makeSharedRoomsViewModel())
        case .sharedRoomDetail(let roomID, let ownerID):
            SharedRoomDetailView(
                navigator: self,
                viewModel: makeSharedRoomDetailViewModel(roomID: roomID, ownerID: ownerID)
            )
        case .sharedItemDetail(let itemID, let roomID, let ownerID):
            SharedItemDetailView(
                viewModel: makeSharedItemDetailViewModel(
                    itemID: itemID,
                    roomID: roomID,
                    ownerID: ownerID
                )
            )
        case .gifts:
            GiftsView(viewModel: makeGiftsViewModel())
        }
    }
}

extension SettingsCoordinator: SharedRoomNavigator {
    func pushSharedItemDetail(itemID: UUID, roomID: UUID, ownerID: UUID) {
        push(.sharedItemDetail(itemID: itemID, roomID: roomID, ownerID: ownerID))
    }
}
