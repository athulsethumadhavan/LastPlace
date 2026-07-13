//
//  HomeCoordinator.swift
//  LastPlace
//
//  Owns the Home tab's `NavigationPath` and builds destination views for each
//  route. Phase 4 fills in real feature views; today it returns typed
//  placeholders so navigation is wired end-to-end.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class HomeCoordinator {
    var path = NavigationPath()

    let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
    }

    func push(_ route: HomeRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }

    @ViewBuilder
    func destination(for route: HomeRoute) -> some View {
        FeaturePlaceholderView(
            title: title(for: route),
            subtitle: "This feature ships in a later phase.",
            symbolName: symbolName(for: route)
        )
    }

    private func title(for route: HomeRoute) -> String {
        switch route {
        case .roomDetail:          return "Room Detail"
        case .createRoom:          return "New Room"
        case .editRoom:            return "Edit Room"
        case .itemDetail:          return "Item Detail"
        case .updateItemLocation:  return "Update Location"
        case .scanRoom:            return "Scan Room"
        }
    }

    private func symbolName(for route: HomeRoute) -> String {
        switch route {
        case .roomDetail:          return "door.left.hand.open"
        case .createRoom:          return "plus.rectangle.on.rectangle"
        case .editRoom:            return "pencil"
        case .itemDetail:          return "shippingbox"
        case .updateItemLocation:  return "mappin.and.ellipse"
        case .scanRoom:            return "camera.viewfinder"
        }
    }
}
