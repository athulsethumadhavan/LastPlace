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

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: SettingsRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }

    @ViewBuilder
    func destination(for route: SettingsRoute) -> some View {
        FeaturePlaceholderView(
            title: title(for: route),
            subtitle: "This section ships in a later phase.",
            symbolName: symbolName(for: route)
        )
    }

    private func title(for route: SettingsRoute) -> String {
        switch route {
        case .privacy:        return "Privacy"
        case .permissions:    return "Permissions"
        case .appearance:     return "Appearance"
        case .dataManagement: return "Data Management"
        }
    }

    private func symbolName(for route: SettingsRoute) -> String {
        switch route {
        case .privacy:        return "hand.raised"
        case .permissions:    return "checkmark.shield"
        case .appearance:     return "paintbrush"
        case .dataManagement: return "externaldrive"
        }
    }
}
