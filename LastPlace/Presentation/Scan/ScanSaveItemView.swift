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
        VStack(spacing: 0) {
            topBar
            Rectangle()
                .fill(AppColor.divider)
                .frame(height: 1)
            content
        }
        .background(AppColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

    private var topBar: some View {
        HStack {
            Button("Cancel") { coordinator.goToReview() }
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityLabel("Cancel and return to review")

            Spacer()

            Text("Save Item")
                .font(AppFont.heading(16))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Button("Save") { saveTapped() }
                .font(AppFont.heading(15))
                .foregroundStyle(viewModel.canSave ? AppColor.accent : AppColor.textTertiary)
                .disabled(!viewModel.canSave)
                .accessibilityLabel("Save item")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroImage

                if !viewModel.detectionLabel.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.accent)
                        Text("Suggested: \(viewModel.detectionLabel) (\(Int(viewModel.confidence * 100))%)")
                            .font(AppFont.body(12.5))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                fieldGroup(title: "Name") {
                    TextField("e.g. Passport", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .accessibilityLabel("Item name")
                }

                fieldGroup(title: "Category") {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(ItemCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColor.textPrimary)
                }

                fieldGroup(title: "Location") {
                    TextField("e.g. Top drawer", text: $viewModel.locationDescription)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Location description")
                }

                fieldGroup(title: "Notes") {
                    TextField("Optional", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityLabel("Notes")
                }

                importantToggleRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let data = viewModel.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
        }
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(AppFont.heading(12, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)
            content()
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
        }
    }

    private var importantToggleRow: some View {
        HStack {
            Text("Mark as important")
                .font(AppFont.body(14.5))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Toggle("", isOn: $viewModel.isImportant)
                .labelsHidden()
                .tint(AppColor.accent)
        }
        .padding(.top, 8)
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
