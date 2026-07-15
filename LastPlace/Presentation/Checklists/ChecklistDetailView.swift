//
//  ChecklistDetailView.swift
//  LastPlace
//

import SwiftUI

struct ChecklistDetailView: View {
    let coordinator: ChecklistCoordinator
    @State private var viewModel: ChecklistDetailViewModel
    @State private var isConfirmingDelete = false

    init(coordinator: ChecklistCoordinator, viewModel: ChecklistDetailViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                if case .idle = viewModel.state { await viewModel.load() }
            }
            .refreshable { await viewModel.load() }
            .confirmationDialog(
                "Delete this checklist?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete checklist", role: .destructive) {
                    Task {
                        if await viewModel.deleteChecklist() {
                            coordinator.popToRoot()
                            coordinator.refreshChecklists()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its items will also be removed. This can't be undone.")
            }
            .alert(
                viewModel.mutationError?.title ?? "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.mutationError != nil },
                    set: { if !$0 { viewModel.mutationError = nil } }
                ),
                actions: { Button("OK", role: .cancel) { viewModel.mutationError = nil } },
                message: { Text(viewModel.mutationError?.message ?? "") }
            )
    }

    private var navigationTitle: String {
        if case .loaded(let detail) = viewModel.state { return detail.checklist.name }
        return "Checklist"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if case .loaded(let detail) = viewModel.state {
                Menu {
                    Button {
                        coordinator.push(.linkItem(checklistID: detail.checklist.id))
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    Button {
                        Task { await viewModel.resetChecklist() }
                    } label: {
                        Label("Reset checklist", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(detail.completedCount == 0)
                    Divider()
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete checklist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Checklist actions")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing here yet",
                message: "This checklist has no items yet.",
                symbolName: "checklist"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let detail):
            loadedView(detail)
        }
    }

    private func loadedView(_ detail: ChecklistDetail) -> some View {
        let sortedEntries = detail.entries.sorted { $0.sortOrder < $1.sortOrder }

        return VStack(spacing: 0) {
            progressHeader(detail)

            if sortedEntries.isEmpty {
                EmptyStateView(
                    title: "Nothing on this list yet",
                    message: "Add work essentials, packing items, or anything you want to check before you go.",
                    symbolName: "plus.circle",
                    primaryAction: EmptyStateAction(
                        title: "Add an item",
                        action: { coordinator.push(.linkItem(checklistID: detail.checklist.id)) }
                    )
                )
                .padding(.top, 24)
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(sortedEntries) { entry in
                            ChecklistEntryRow(
                                entry: entry,
                                linkedItem: entry.linkedItemID.flatMap { viewModel.linkedItems[$0] },
                                onToggle: { Task { await viewModel.toggle(entry.id) } }
                            )
                        }
                        .onDelete { offsets in
                            deleteEntries(at: offsets, from: sortedEntries)
                        }
                    }
                    Section {
                        Button {
                            coordinator.push(.linkItem(checklistID: detail.checklist.id))
                        } label: {
                            Label("Add item", systemImage: "plus.circle")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func progressHeader(_ detail: ChecklistDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(detail.completedCount) of \(detail.totalCount) done")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            if detail.totalCount > 0 {
                ProgressView(value: detail.progress)
                    .tint(.accentColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func deleteEntries(at offsets: IndexSet, from entries: [ChecklistEntry]) {
        let ids = offsets.map { entries[$0].id }
        Task {
            for id in ids {
                await viewModel.deleteEntry(id)
            }
        }
    }
}
