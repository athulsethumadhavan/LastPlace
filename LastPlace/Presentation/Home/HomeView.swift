//
//  HomeView.swift
//  LastPlace
//
//  Placeholder Home tab. Wires `navigationDestination(for:)` so the coordinator
//  builds every pushed route. Real content (rooms grid, recent items strip,
//  important shortcut, scan CTA) arrives in Phase 4.
//

import SwiftUI

struct HomeView: View {
    @Bindable var coordinator: HomeCoordinator

    var body: some View {
        FeaturePlaceholderView(
            title: "Home",
            subtitle: "Your rooms, recent items and important shortcuts will live here.",
            symbolName: "house.fill"
        )
        .navigationTitle("LastPlace")
        .navigationDestination(for: HomeRoute.self) { route in
            coordinator.destination(for: route)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(coordinator: HomeCoordinator.previewCoordinator())
    }
}

@MainActor
private extension HomeCoordinator {
    static func previewCoordinator() -> HomeCoordinator {
        HomeCoordinator(container: try! AppDependencyContainer.makePreview())
    }
}
