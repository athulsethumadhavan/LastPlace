//
//  CreateRoomView.swift
//  LastPlace
//

import SwiftUI

struct CreateRoomView: View {
    let coordinator: HomeCoordinator
    @State private var viewModel: CreateRoomViewModel
    @FocusState private var isNameFocused: Bool

    init(coordinator: HomeCoordinator, viewModel: CreateRoomViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
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
        .navigationTitle("New Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveTapped() }
                    .disabled(!viewModel.canSave)
                    .accessibilityLabel("Save room")
            }
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

    private func saveTapped() {
        Task {
            if let _ = await viewModel.save() {
                coordinator.popLast()
                coordinator.refreshHome()
            }
        }
    }
}
