//
//  MainTabView.swift
//  LastPlace
//

import SwiftUI
import UIKit

struct MainTabView: View {
    let container: AppDependencyContainer
    @State private var coordinator: MainTabCoordinator

    init(container: AppDependencyContainer) {
        self.container = container
        _coordinator = State(initialValue: MainTabView.makeCoordinator(container: container))
        MainTabView.configureTabBarAppearance()
    }

    var body: some View {
        // Reverted to the native `TabView`/`.tabItem` bar — the custom
        // floating glass bar (`FloatingTabBar`, kept around unused in case
        // this gets revisited) sat slightly higher than the system bar's
        // usual position and lived outside every `NavigationStack`, which
        // meant each tab's root screen had to manually pad its scroll
        // content to clear it. Native `TabView` reserves that space itself
        // via the safe area, so screens no longer need that manual padding.
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
        .tint(AppColor.accent)
    }

    /// `.tint(AppColor.accent)` above only colors the *selected* tab —
    /// unselected icons/labels default to the system's own gray, which
    /// doesn't track our light/dark `AppColor` tokens (and can end up
    /// looking closer to black than gray depending on appearance). SwiftUI
    /// has no direct modifier for the unselected state, so this reaches
    /// into `UITabBarAppearance` once at startup to pin it to
    /// `AppColor.textTertiary` instead. Selected-state colors are left
    /// untouched so `.tint` keeps controlling those.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.normal.iconColor = AppColor.textTertiaryUIColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: AppColor.textTertiaryUIColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
