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

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: SettingsRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }

    func notifyAllDataDeleted() {
        onAllDataDeleted?()
    }

    // MARK: View-model factories

    private func makeAppearanceViewModel() -> AppearanceViewModel {
        AppearanceViewModel(store: container.appearanceSettings)
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

    // MARK: Destinations

    @ViewBuilder
    func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .privacy:
            PrivacyView()
        case .permissions:
            PermissionsView()
        case .appearance:
            AppearanceView(viewModel: makeAppearanceViewModel())
        case .security:
            SecurityView(viewModel: makeSecurityViewModel())
        case .dataManagement:
            DataManagementView(coordinator: self, viewModel: makeDataManagementViewModel())
        }
    }
}
