//
//  EditRoomView.swift
//  LastPlace
//

import SwiftUI

struct EditRoomView: View {
    let coordinator: HomeCoordinator
    @State private var viewModel: EditRoomViewModel
    @FocusState private var isNameFocused: Bool

    init(coordinator: HomeCoordinator, viewModel: EditRoomViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Edit Room")
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
            .onAppear { isNameFocused = true }
            .interactiveDismissDisabled(viewModel.isSaving)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing to edit",
                message: "This room couldn't be loaded.",
                symbolName: "house"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded:
            form
        }
    }

    private var form: some View {
        Form {
            Section("Name") {
                TextField("e.g. Living Room", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .accessibilityLabel("Room name")
            }

            Section("Icon") {
                iconPicker
            }
        }
    }

    private var iconPicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
            spacing: 8
        ) {
            ForEach(Room.iconSuggestions, id: \.self) { symbol in
                IconChoice(
                    symbol: symbol,
                    isSelected: viewModel.iconName == symbol,
                    action: { viewModel.iconName = symbol }
                )
            }
        }
        .padding(.vertical, 4)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") { saveTapped() }
                .disabled(!viewModel.canSave)
                .accessibilityLabel("Save room")
        }
    }

    private func saveTapped() {
        Task {
            if await viewModel.save() {
                coordinator.popLast()
                coordinator.refreshRoomDetail()
                coordinator.refreshHome()
            }
        }
    }
}
