//
//  ChecklistCoordinator.swift
//  LastPlace
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ChecklistCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: ChecklistRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }

    @ViewBuilder
    func destination(for route: ChecklistRoute) -> some View {
        switch route {
        case .detail:
            FeaturePlaceholderView(
                title: "Checklist",
                subtitle: "Detail view arrives in a later phase.",
                symbolName: "checklist"
            )
        case .create:
            FeaturePlaceholderView(
                title: "New Checklist",
                subtitle: "Creation flow arrives in a later phase.",
                symbolName: "plus.circle"
            )
        case .linkItem:
            FeaturePlaceholderView(
                title: "Link Item",
                subtitle: "Item linking arrives in a later phase.",
                symbolName: "link"
            )
        }
    }
}
