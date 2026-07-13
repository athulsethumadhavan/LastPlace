//
//  SearchCoordinator.swift
//  LastPlace
//

import SwiftUI
import Observation

@Observable
@MainActor
final class SearchCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: SearchRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }

    @ViewBuilder
    func destination(for route: SearchRoute) -> some View {
        switch route {
        case .itemDetail:
            FeaturePlaceholderView(
                title: "Item Detail",
                subtitle: "This feature ships in a later phase.",
                symbolName: "shippingbox"
            )
        }
    }
}
