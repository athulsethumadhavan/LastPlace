//
//  MainTabCoordinator.swift
//  LastPlace
//
//  Owns tab selection and the four per-feature coordinators. Each feature
//  coordinator owns its own `NavigationPath` so pushes on one tab don't affect
//  another.
//

import Foundation
import Observation

@Observable
@MainActor
final class MainTabCoordinator {
    var selectedTab: MainTab = .home

    let homeCoordinator: HomeCoordinator
    let searchCoordinator: SearchCoordinator
    let checklistCoordinator: ChecklistCoordinator
    let settingsCoordinator: SettingsCoordinator

    init(
        homeCoordinator: HomeCoordinator,
        searchCoordinator: SearchCoordinator,
        checklistCoordinator: ChecklistCoordinator,
        settingsCoordinator: SettingsCoordinator
    ) {
        self.homeCoordinator = homeCoordinator
        self.searchCoordinator = searchCoordinator
        self.checklistCoordinator = checklistCoordinator
        self.settingsCoordinator = settingsCoordinator
    }

    /// Reloads every tab's root screen. Used after a sync that replaced the
    /// local store (an account switch), where the tabs mounted against an
    /// empty database and would otherwise sit empty until the person
    /// navigated away and back.
    func refreshAllTabs() {
        homeCoordinator.refreshHome()
        checklistCoordinator.refreshChecklists()
        Task { await searchCoordinator.searchViewModel.refresh() }
    }

    /// Deep-link entry point from a tapped push notification (see
    /// `PushNotificationRelay.onNotificationTapped`, wired in
    /// `MainTabView.makeCoordinator`). Each case replaces the target tab's
    /// navigation stack rather than pushing on top of it -- a notification
    /// tap is a fresh destination, not a continuation of wherever the user
    /// happened to leave that tab.
    func open(_ destination: PushNotificationDestination) {
        switch destination {
        case .item(let itemID):
            selectedTab = .home
            homeCoordinator.popToRoot()
            homeCoordinator.push(.itemDetail(itemID: itemID))
        case .gifts:
            selectedTab = .settings
            settingsCoordinator.popToRoot()
            settingsCoordinator.push(.gifts)
        }
    }
}
