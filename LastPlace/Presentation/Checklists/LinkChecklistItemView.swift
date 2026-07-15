//
//  LinkChecklistItemView.swift
//  LastPlace
//
//  Lets the user add a checklist entry either by typing a free-text title or
//  by picking a saved item to link. Tapping a picked item adds it immediately
//  and stays on screen so several items can be added in one pass — matches
//  how someone would actually build a "Work essentials" or packing list.
//

import SwiftUI

struct LinkChecklistItemView: View {
    let coordinator: ChecklistCoordinator
    @State private var viewModel: LinkChecklistItemViewModel
    @FocusState private var isCustomTitleFocused: Bool
    @FocusState private var isCustomLocationFocused: Bool

    init(coordinator: ChecklistCoordinator, viewModel: LinkChecklistItemViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Add item")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search your saved items")
            .task {
                if case .idle = viewModel.state { await viewModel.load() }
            }
            .task(id: viewModel.query) {
                guard case .idle = viewModel.state else {
                    await viewModel.search(query: viewModel.query)
                    return
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
            .onDisappear { coordinator.refreshActiveChecklistDetail() }
    }

    private var content: some View {
        List {
            Section {
                TextField("Item title", text: $viewModel.customTitle)
                    .textInputAutocapitalization(.words)
                    .focused($isCustomTitleFocused)
                    .submitLabel(.next)
                    .onSubmit { isCustomLocationFocused = true }
                    .accessibilityLabel("Custom item title")

                TextField("Location (optional)", text: $viewModel.customLocation)
                    .textInputAutocapitalization(.sentences)
                    .focused($isCustomLocationFocused)
                    .submitLabel(.done)
                    .onSubmit { addCustomTapped() }
                    .accessibilityLabel("Custom item location")

                Button("Add item") { addCustomTapped() }
                    .disabled(!viewModel.canAddCustom)
                    .accessibilityLabel("Add custom item")
            } header: {
                Text("Add without linking")
            } footer: {
                Text("Location is optional — worth adding if you already know where it is. Or pick a saved item below to link it and pull in its current location automatically.")
            }

            resultsSection
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var resultsSection: some View {
        switch viewModel.state {
        case .idle, .loading:
            Section {
                LoadingView()
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        case .empty:
            Section {
                Text("You haven't saved any items yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .failed(let error):
            Section {
                ErrorStateView(error: error, retryAction: { Task { await viewModel.search(query: viewModel.query) } })
            }
            .listRowBackground(Color.clear)
        case .loaded(let results):
            if results.hasMatches {
                Section("Your items") {
                    ForEach(results.matches) { item in
                        PickableItemRow(item: item, isAdded: viewModel.isLinked(item.id)) {
                            Task { await viewModel.addLinked(item: item) }
                        }
                    }
                }
            } else if !results.suggested.isEmpty {
                Section(suggestedSectionTitle) {
                    ForEach(results.suggested) { item in
                        PickableItemRow(item: item, isAdded: viewModel.isLinked(item.id)) {
                            Task { await viewModel.addLinked(item: item) }
                        }
                    }
                }
            }
        }
    }

    private var suggestedSectionTitle: String {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Recent & important"
            : "No matches — try one of these"
    }

    private func addCustomTapped() {
        Task {
            await viewModel.addCustom()
            isCustomTitleFocused = false
            isCustomLocationFocused = false
        }
    }
}
