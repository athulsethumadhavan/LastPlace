//
//  DataManagementView.swift
//  LastPlace
//

import SwiftUI

struct DataManagementView: View {
    let coordinator: SettingsCoordinator
    @State private var viewModel: DataManagementViewModel
    @State private var isConfirmingDelete = false
    @State private var showsDeletedConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(coordinator: SettingsCoordinator, viewModel: DataManagementViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Data Management", onBack: { dismiss() })
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
            .task {
                if case .idle = viewModel.state { await viewModel.load() }
            }
            .refreshable { await viewModel.load() }
            .confirmationDialog(
                "Delete all your data?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Task {
                        if await viewModel.deleteAll() {
                            showsDeletedConfirmation = true
                            coordinator.notifyAllDataDeleted()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every room, item, and checklist, along with their saved photos. This can't be undone.")
            }
            .alert(
                viewModel.error?.title ?? "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.error = nil } }
                ),
                actions: { Button("OK", role: .cancel) { viewModel.error = nil } },
                message: { Text(viewModel.error?.message ?? "") }
            )
            .alert("All data deleted", isPresented: $showsDeletedConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Every room, item, and checklist has been removed.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing to show",
                message: "Your data summary couldn't be loaded.",
                symbolName: "externaldrive"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let summary):
            List {
                summarySection(summary)
                deleteSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
        }
    }

    private func summarySection(_ summary: DataSummary) -> some View {
        Section {
            row("Rooms", value: "\(summary.roomCount)")
            row("Items", value: "\(summary.itemCount)")
            row("Checklists", value: "\(summary.checklistCount)")
        } header: {
            Text("What's saved")
                .font(AppFont.heading(12, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text(value)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textSecondary)
        }
        .listRowBackground(AppColor.background)
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                HStack {
                    Text("Delete All Data")
                        .font(AppFont.body(15))
                    Spacer()
                    if viewModel.isDeleting {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isDeleting)
            .listRowBackground(AppColor.background)
        } footer: {
            Text("Permanently removes every room, item, and checklist, along with their saved photos. This can't be undone.")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textTertiary)
        }
    }
}
