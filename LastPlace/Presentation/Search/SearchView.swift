//
//  SearchView.swift
//  LastPlace
//

import SwiftUI

struct SearchView: View {
    @Bindable var coordinator: SearchCoordinator

    var body: some View {
        FeaturePlaceholderView(
            title: "Search",
            subtitle: "Find items by name, room, or where you last saw them.",
            symbolName: "magnifyingglass"
        )
        .navigationTitle("Search")
        .navigationDestination(for: SearchRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
    }
}
