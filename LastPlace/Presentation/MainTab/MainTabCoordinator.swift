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
}
