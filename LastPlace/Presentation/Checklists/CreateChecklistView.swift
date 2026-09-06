//
//  CreateChecklistView.swift
//  LastPlace
//

import SwiftUI

struct CreateChecklistView: View {
    let coordinator: ChecklistCoordinator
    @State private var viewModel: CreateChecklistViewModel
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCustomTypeFocused: Bool

    init(coordinator: ChecklistCoordinator, viewModel: CreateChecklistViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Work essentials", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .accessibilityLabel("Checklist name")
            }

            Section("Type") {
                typePicker
                if viewModel.isCustomType {
                    TextField("Custom type name", text: $viewModel.customTypeName)
                        .textInputAutocapitalization(.words)
                        .focused($isCustomTypeFocused)
                        .accessibilityLabel("Custom checklist type")
                }
            }
        }
        .navigationTitle("New Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveTapped() }
                    .disabled(!viewModel.canSave)
                    .accessibilityLabel("Save checklist")
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

    private var typePicker: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(CreateChecklistViewModel.presetTypes, id: \.self) { type in
                TypeChoice(
                    type: type,
                    isSelected: !viewModel.isCustomType && viewModel.selectedPreset == type,
                    action: {
                        viewModel.isCustomType = false
                        viewModel.selectedPreset = type
                    }
                )
            }
            TypeChoice(
                type: .custom("Custom"),
                isSelected: viewModel.isCustomType,
                action: { viewModel.isCustomType = true }
            )
        }
        .padding(.vertical, 4)
    }

    private func saveTapped() {
        Task {
            if let _ = await viewModel.save() {
                coordinator.popLast()
                coordinator.refreshChecklists()
            }
        }
    }
}

private struct TypeChoice: View {
    let type: ChecklistType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.symbolName)
                    .font(.title3)
                Text(type.displayName)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
