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

    init(coordinator: SearchCoordinator, viewModel: SearchViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search items, rooms, or locations")
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

    private func resultsList(_ results: SearchResults) -> some View {
        List {
            if results.hasMatches {
                Section("Results") {
                    ForEach(results.matches) { item in
                        SearchResultRow(item: item) {
                            coordinator.push(.itemDetail(itemID: item.id))
                        }
                    }
                }
            } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    Text("No matches for \u{201C}\(viewModel.query)\u{201D}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !results.suggested.isEmpty {
                    Section("Recent & important") {
                        ForEach(results.suggested) { item in
                            SearchResultRow(item: item) {
                                coordinator.push(.itemDetail(itemID: item.id))
                            }
                        }
                    }
                }
            } else if !results.suggested.isEmpty {
                Section("Recent & important") {
                    ForEach(results.suggested) { item in
                        SearchResultRow(item: item) {
                            coordinator.push(.itemDetail(itemID: item.id))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
