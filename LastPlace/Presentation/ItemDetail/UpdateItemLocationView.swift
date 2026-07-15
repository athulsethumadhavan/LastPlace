//
//  UpdateItemLocationView.swift
//  LastPlace
//
//  Lets the user record where an item is currently located. Saving appends a
//  snapshot and updates the item so the detail screen and its parents show
//  the fresh location on return.
//

import SwiftUI

struct UpdateItemLocationView: View {
    let navigator: ItemDetailNavigator
    @State private var viewModel: UpdateItemLocationViewModel
    @FocusState private var isLocationFocused: Bool

    init(navigator: ItemDetailNavigator, viewModel: UpdateItemLocationViewModel) {
        self.navigator = navigator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Update location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                if case .idle = viewModel.loadState { await viewModel.load() }
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
            .interactiveDismissDisabled(viewModel.isSaving)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing to update",
                message: "The item couldn't be loaded.",
                symbolName: "shippingbox"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded:
            form
        }
    }

    private var form: some View {
        Form {
            Section("Where is it now?") {
                TextField("e.g. Top drawer of the desk", text: $viewModel.locationDescription, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
                    .focused($isLocationFocused)
                    .accessibilityLabel("Location description")
            }

            Section {
                Text("Saving records a new snapshot so you can see this item's location history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { isLocationFocused = true }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { navigator.popTop() }
                .accessibilityLabel("Cancel location update")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") { saveTapped() }
                .disabled(!viewModel.canSave)
                .accessibilityLabel("Save location")
        }
    }

    private func saveTapped() {
        Task {
            if await viewModel.save() {
                navigator.popTop()
                navigator.refreshAfterItemMutation()
            }
        }
    }
}
