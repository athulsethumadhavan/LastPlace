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
        VStack(spacing: 0) {
            header
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ChecklistRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.refresh() }
        .overlay(alignment: .bottomTrailing) {
            if showsFloatingAddButton {
                addChecklistButton
            }
        }
    }

    private var header: some View {
        Text("Checklists")
            .font(AppFont.heading(30))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Hidden while the empty state is showing — that screen already has its
    /// own prominent "Create a checklist" CTA, matching the same convention
    /// as `HomeView`'s floating add-room button.
    private var showsFloatingAddButton: Bool {
        if case .loaded = viewModel.state { return true }
        return false
    }

    private var addChecklistButton: some View {
        Button {
            coordinator.push(.create)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AppColor.accent, in: Circle())
                .appCardShadow()
        }
        .accessibilityLabel("New checklist")
        .padding(.trailing, 20)
        .padding(.bottom, 16)
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

    /// Same grouped-card treatment as `SettingsView`'s rows — a single
    /// rounded, shadowed surface with a thin divider between entries rather
    /// than the flat full-bleed list this used to be. Since that means
    /// leaving `List` behind, swipe-to-delete goes with it; a long-press
    /// context menu takes its place, and deleting is still reachable from a
    /// checklist's own detail screen either way.
    private func list(_ checklists: [Checklist]) -> some View {
        ScrollView {
            checklistsCard {
                ForEach(Array(checklists.enumerated()), id: \.element.id) { index, checklist in
                    ChecklistRow(
                        checklist: checklist,
                        progress: viewModel.progressByChecklistID[checklist.id],
                        showsDivider: index < checklists.count - 1
                    ) {
                        coordinator.push(.detail(checklistID: checklist.id))
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteChecklist(id: checklist.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    private func checklistsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
            .appCardShadow()
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
        .frame(maxHeight: .infinity, alignment: .center)
    }
}
