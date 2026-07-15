//
//  ScanSaveItemView.swift
//  LastPlace
//
//  Save-item form launched when the user taps a detection chip. Pre-filled by
//  `ScanSaveItemViewModel`; on success it returns to the review screen so the
//  user can continue saving items from the same scan.
//

import SwiftUI

struct ScanSaveItemView: View {
    let coordinator: ScanCoordinator
    let homeCoordinator: HomeCoordinator
    @State private var viewModel: ScanSaveItemViewModel
    @FocusState private var isNameFocused: Bool

    init(coordinator: ScanCoordinator, homeCoordinator: HomeCoordinator, viewModel: ScanSaveItemViewModel) {
        self.coordinator = coordinator
        self.homeCoordinator = homeCoordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            if let data = viewModel.imageData, let image = UIImage(data: data) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if !viewModel.detectionLabel.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text("Suggested: \(viewModel.detectionLabel) (\(Int(viewModel.confidence * 100))%)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Name") {
                TextField("e.g. Passport", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .accessibilityLabel("Item name")
            }

            Section("Category") {
                Picker("Category", selection: $viewModel.category) {
                    ForEach(ItemCategory.allCases, id: \.self) { category in
                        Label(category.displayName, systemImage: category.symbolName)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Location") {
                TextField("e.g. Top drawer", text: $viewModel.locationDescription)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Location description")
            }

            Section("Notes") {
                TextField("Optional", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityLabel("Notes")
            }

            Section {
                Toggle("Mark as important", isOn: $viewModel.isImportant)
            }
        }
        .navigationTitle("Save item")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { coordinator.goToReview() }
                    .accessibilityLabel("Cancel and return to review")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveTapped() }
                    .disabled(!viewModel.canSave)
                    .accessibilityLabel("Save item")
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
        .onAppear {
            if viewModel.name.isEmpty { isNameFocused = true }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func saveTapped() {
        Task {
            if let _ = await viewModel.save() {
                homeCoordinator.refreshRoomDetail()
                homeCoordinator.refreshHome()
                coordinator.goToReview()
            }
        }
    }
}
