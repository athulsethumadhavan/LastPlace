//
//  SearchItemsUseCase.swift
//  LastPlace
//
//  Returns matches AND a fallback set of suggestions so the view model doesn't
//  branch on the empty case. When the query is blank we return an empty
//  `matches` list and let the caller show the suggestions.
//

import Foundation

protocol SearchItemsUseCase: Sendable {
    func execute(query: String) async throws -> SearchResults
}

struct DefaultSearchItemsUseCase: SearchItemsUseCase {
    let itemRepository: ItemRepository
    let suggestedLimit: Int

    init(itemRepository: ItemRepository, suggestedLimit: Int = 12) {
        self.itemRepository = itemRepository
        self.suggestedLimit = suggestedLimit
    }

    func execute(query: String) async throws -> SearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let matches: [StoredItem]
        if trimmed.isEmpty {
            matches = []
        } else {
            matches = try await itemRepository.search(query: trimmed)
        }

        if !matches.isEmpty {
            return SearchResults(matches: matches, suggested: [])
        }

        let important = try await itemRepository.fetchImportantItems()
        let recents = try await itemRepository.fetchRecentItems(limit: suggestedLimit)

        var seen = Set<UUID>()
        var combined: [StoredItem] = []
        for item in important + recents where seen.insert(item.id).inserted {
            combined.append(item)
            if combined.count == suggestedLimit { break }
        }
        return SearchResults(matches: [], suggested: combined)
    }
}
