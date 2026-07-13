//
//  MainTabView.swift
//  LastPlace
//
//  Hosts the four tab feature stacks. Each tab is a `NavigationStack` bound to
//  its own coordinator's path so pushes stay scoped per tab.
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
                HomeView(coordinator: coordinator.homeCoordinator)
            }
            .tabItem { Label(MainTab.home.title, systemImage: MainTab.home.symbolName) }
            .tag(MainTab.home)

            NavigationStack(path: Binding(
                get: { coordinator.searchCoordinator.path },
                set: { coordinator.searchCoordinator.path = $0 }
            )) {
                SearchView(coordinator: coordinator.searchCoordinator)
            }
            .tabItem { Label(MainTab.search.title, systemImage: MainTab.search.symbolName) }
            .tag(MainTab.search)

            NavigationStack(path: Binding(
                get: { coordinator.checklistCoordinator.path },
                set: { coordinator.checklistCoordinator.path = $0 }
            )) {
                ChecklistsListView(coordinator: coordinator.checklistCoordinator)
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
        MainTabCoordinator(
            homeCoordinator: HomeCoordinator(container: container),
            searchCoordinator: SearchCoordinator(container: container),
            checklistCoordinator: ChecklistCoordinator(container: container),
            settingsCoordinator: SettingsCoordinator(container: container)
        )
    }
}
