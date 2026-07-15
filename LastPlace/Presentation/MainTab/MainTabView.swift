//
//  MainTabView.swift
//  LastPlace
//

import SwiftUI

struct MainTabView: View {
    let container: AppDependencyContainer
    @State private var coordinator: MainTabCoordinator

    init(container: AppDependencyContainer) {
        self.container = container
        _coordinator = State(initialValue: MainTabView.makeCoordinator(container: container))
    }

    var body: some View {
        TabView(selection: Binding(
            get: { coordinator.selectedTab },
            set: { coordinator.selectedTab = $0 }
        )) {
            NavigationStack(path: Binding(
                get: { coordinator.homeCoordinator.path },
                set: { coordinator.homeCoordinator.path = $0 }
            )) {
                HomeView(
                    coordinator: coordinator.homeCoordinator,
                    viewModel: coordinator.homeCoordinator.homeViewModel
                )
            }
            .tabItem { Label(MainTab.home.title, systemImage: MainTab.home.symbolName) }
            .tag(MainTab.home)

            NavigationStack(path: Binding(
                get: { coordinator.searchCoordinator.path },
                set: { coordinator.searchCoordinator.path = $0 }
            )) {
                SearchView(
                    coordinator: coordinator.searchCoordinator,
                    viewModel: coordinator.searchCoordinator.searchViewModel
                )
            }
            .tabItem { Label(MainTab.search.title, systemImage: MainTab.search.symbolName) }
            .tag(MainTab.search)

            NavigationStack(path: Binding(
                get: { coordinator.checklistCoordinator.path },
                set: { coordinator.checklistCoordinator.path = $0 }
            )) {
                ChecklistsListView(
                    coordinator: coordinator.checklistCoordinator,
                    viewModel: coordinator.checklistCoordinator.checklistsListViewModel
                )
            }
            .tabItem { Label(MainTab.checklists.title, systemImage: MainTab.checklists.symbolName) }
            .tag(MainTab.checklists)

            NavigationStack(path: Binding(
                get: { coordinator.settingsCoordinator.path },
                set: { coordinator.settingsCoordinator.path = $0 }
            )) {
                SettingsView(coordinator: coordinator.settingsCoordinator)
            }
            .tabItem { Label(MainTab.settings.title, systemImage: MainTab.settings.symbolName) }
            .tag(MainTab.settings)
        }
    }

    @MainActor
    private static func makeCoordinator(container: AppDependencyContainer) -> MainTabCoordinator {
        let homeCoordinator = HomeCoordinator(container: container)
        let searchCoordinator = SearchCoordinator(container: container)
        let checklistCoordinator = ChecklistCoordinator(container: container)
        let settingsCoordinator = SettingsCoordinator(container: container)

        // "Delete All Data" in Settings mutates state the other three tabs
        // have already loaded and cached in their own coordinator-owned view
        // models; none of them would otherwise notice until the user forced
        // a pull-to-refresh.
        settingsCoordinator.onAllDataDeleted = { [weak homeCoordinator, weak searchCoordinator, weak checklistCoordinator] in
            homeCoordinator?.refreshHome()
            checklistCoordinator?.refreshChecklists()
            if let searchCoordinator {
                Task { await searchCoordinator.searchViewModel.refresh() }
            }
        }

        return MainTabCoordinator(
            homeCoordinator: homeCoordinator,
            searchCoordinator: searchCoordinator,
            checklistCoordinator: checklistCoordinator,
            settingsCoordinator: settingsCoordinator
        )
    }
}
