//
//  SearchViewModel.swift
//  LastPlace
//
//  Backs the Search tab. Blank query shows a "Recent & Important" fallback
//  (via `SearchItemsUseCase`'s `suggested` list) instead of an empty screen;
//  typed queries debounce briefly before hitting the repository so fast
//  typing doesn't fire a query per keystroke.
//

import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    private(set) var state: LoadableState<SearchResults> = .idle

    private let searchItemsUseCase: SearchItemsUseCase
    private let logger: AppLogger

    /// How long to wait after the last keystroke before searching. Blank-query
    /// lookups (initial load, clearing the field) skip the delay entirely.
    private let debounceNanoseconds: UInt64 = 200_000_000

    init(searchItems: SearchItemsUseCase, logger: AppLogger) {
        self.searchItemsUseCase = searchItems
        self.logger = logger
    }

    /// Initial load on first appearance — shows suggestions before the user types.
    func load() async {
        guard case .idle = state else { return }
        await performSearch(query: query)
    }

    /// Called from `.task(id: viewModel.query)`. SwiftUI cancels the previous
    /// task automatically when the query changes, so the sleep below acts as a
    /// debounce: only the last keystroke's task survives long enough to search.
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }
        await performSearch(query: query)
    }

    func refresh() async {
        await performSearch(query: query)
    }

    private func performSearch(query: String) async {
        state = .loading
        do {
            let results = try await searchItemsUseCase.execute(query: query)
            state = results.isEmpty ? .empty : .loaded(results)
        } catch {
            logger.error("Search failed", error: error, category: "search")
            state = .failed(UserFacingError.from(error))
        }
    }
}
