//
//  SearchView.swift
//  LastPlace
//
//  Blank query shows recent + important items so the screen is never empty;
//  typing filters to matches across name, category, room, location, and
//  notes (see `SearchItemsUseCase`).
//

import SwiftUI

struct SearchView: View {
    let coordinator: SearchCoordinator
    @State private var viewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool

    init(coordinator: SearchCoordinator, viewModel: SearchViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(AppColor.divider)
                .frame(height: 1)
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SearchRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .task(id: viewModel.query) {
            guard case .idle = viewModel.state else {
                await viewModel.search(query: viewModel.query)
                return
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search")
                .font(AppFont.heading(30))
                .foregroundStyle(AppColor.textPrimary)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                    TextField("Search items, rooms, or locations", text: $viewModel.query)
                        .font(AppFont.body(14.5))
                        .foregroundStyle(AppColor.textPrimary)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(AppColor.divider, lineWidth: 1)
                )

                if isSearchFocused || !viewModel.query.isEmpty {
                    Button("Cancel") {
                        viewModel.query = ""
                        isSearchFocused = false
                    }
                    .font(AppFont.body(14.5))
                    .foregroundStyle(AppColor.accent)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing saved yet",
                message: "Scan a room or add items manually, then come back to search for them.",
                symbolName: "magnifyingglass"
            )
        case .failed(let error):
            ErrorStateView(error: error, retryAction: { Task { await viewModel.refresh() } })
        case .loaded(let results):
            resultsList(results)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppFont.heading(12, weight: .semibold))
            .foregroundStyle(AppColor.textSecondary)
            .kerning(0.5)
    }

    private func resultsList(_ results: SearchResults) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if results.hasMatches {
                    sectionLabel("Results")
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    resultRows(results.matches)
                } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No matches for \u{201C}\(viewModel.query)\u{201D}")
                        .font(AppFont.body(14.5))
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.top, 16)
                    if !results.suggested.isEmpty {
                        sectionLabel("Recent & important")
                            .padding(.top, 22)
                            .padding(.bottom, 10)
                        resultRows(results.suggested)
                    }
                } else if !results.suggested.isEmpty {
                    sectionLabel("Recent & important")
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    resultRows(results.suggested)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func resultRows(_ items: [StoredItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                SearchResultRow(item: item) {
                    coordinator.push(.itemDetail(itemID: item.id))
                }
                Rectangle()
                    .fill(AppColor.divider)
                    .frame(height: 1)
            }
        }
    }
}
