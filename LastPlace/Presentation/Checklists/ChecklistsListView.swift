//
//  ChecklistsListView.swift
//  LastPlace
//

import SwiftUI

struct ChecklistsListView: View {
    let coordinator: ChecklistCoordinator
    @State private var viewModel: ChecklistsListViewModel

    init(coordinator: ChecklistCoordinator, viewModel: ChecklistsListViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Checklists")
            .toolbar { toolbarContent }
            .navigationDestination(for: ChecklistRoute.self) { route in
                coordinator.destination(for: route)
                    .toolbar(.hidden, for: .tabBar)
            }
            .task {
                if case .idle = viewModel.state { await viewModel.load() }
            }
            .refreshable { await viewModel.refresh() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                coordinator.push(.create)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("New checklist")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Loading your checklists…")
        case .empty:
            emptyStateView
        case .failed(let error):
            ErrorStateView(error: error, retryAction: { Task { await viewModel.refresh() } })
        case .loaded(let checklists):
            list(checklists)
        }
    }

    private func list(_ checklists: [Checklist]) -> some View {
        List {
            ForEach(checklists) { checklist in
                ChecklistRow(
                    checklist: checklist,
                    progress: viewModel.progressByChecklistID[checklist.id]
                ) {
                    coordinator.push(.detail(checklistID: checklist.id))
                }
            }
            .onDelete { offsets in
                deleteChecklists(at: offsets, from: checklists)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        EmptyStateView(
            title: "No checklists yet",
            message: "Create lists like Work, Airport, or Gym so you can check everything's ready before you go.",
            symbolName: "checklist",
            primaryAction: EmptyStateAction(
                title: "Create a checklist",
                action: { coordinator.push(.create) }
            )
        )
        .padding(.top, 32)
    }

    private func deleteChecklists(at offsets: IndexSet, from checklists: [Checklist]) {
        let ids = offsets.map { checklists[$0].id }
        Task {
            for id in ids {
                await viewModel.deleteChecklist(id: id)
            }
        }
    }
}
