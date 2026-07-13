//
//  ChecklistsListView.swift
//  LastPlace
//

import SwiftUI

struct ChecklistsListView: View {
    @Bindable var coordinator: ChecklistCoordinator

    var body: some View {
        FeaturePlaceholderView(
            title: "Checklists",
            subtitle: "Leaving-home lists like Work, Airport, Gym — coming soon.",
            symbolName: "checklist"
        )
        .navigationTitle("Checklists")
        .navigationDestination(for: ChecklistRoute.self) { route in
            coordinator.destination(for: route)
        }
    }
}
