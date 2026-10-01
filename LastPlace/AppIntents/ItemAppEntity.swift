//
//  ItemAppEntity.swift
//  LastPlace
//
//  App Intents' representation of a saved item. Originally `FindItemIntent`
//  and `AddChecklistEntryIntent` took a plain `itemName: String`, but App
//  Intents' shortcut-phrase validator rejects that: only `AppEntity` and
//  `AppEnum` types are allowed as parameters referenced inside a spoken
//  phrase. Routing through this entity instead of free text is also just a
//  better fit for voice — Siri resolves "passport" against real saved items
//  via `ItemEntityQuery`'s matching rather than taking a dictated string on
//  faith. That matching deliberately commits to its own single best guess
//  (see `entities(matching:)`) instead of handing Siri a list to pick from.
//

import AppIntents
import Foundation

struct ItemAppEntity: AppEntity {
    let id: UUID
    let name: String
    let locationDescription: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Item"
    static var defaultQuery = ItemEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(locationDescription)")
    }
}

struct ItemEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [ItemAppEntity.ID]) async throws -> [ItemAppEntity] {
        let container = try IntentDependencies.make()
        var results: [ItemAppEntity] = []
        for id in identifiers {
            if let item = try? await container.itemRepository.fetchItem(itemID: id) {
                results.append(
                    ItemAppEntity(id: item.id, name: item.name, locationDescription: item.locationDescription)
                )
            }
        }
        return results
    }

    /// Backs the picker Siri/Shortcuts show when an item parameter is left
    /// unresolved — recent items are the most likely thing someone's asking
    /// about, same fallback `SearchItemsUseCase` uses for a blank query.
    @MainActor
    func suggestedEntities() async throws -> [ItemAppEntity] {
        let container = try IntentDependencies.make()
        let recents = try await container.itemRepository.fetchRecentItems(
            limit: container.configuration.searchSuggestedLimit
        )
        return recents.map { ItemAppEntity(id: $0.id, name: $0.name, locationDescription: $0.locationDescription) }
    }
}

extension ItemEntityQuery: EntityStringQuery {
    /// Lets Siri match a spoken item name ("passport") against saved items,
    /// reusing the same search the Search tab and `SearchItemsUseCase` use.
    ///
    /// Returns at most one entity -- our own single best guess -- rather
    /// than every item `search(query:)` found. Handing Siri a list here is
    /// what produces a "Which one?" prompt even for an unambiguous name:
    /// this query's only job is resolving one spoken phrase to one item, so
    /// narrowing to our best match ourselves is the right call rather than
    /// deferring it to a picker built from every loose match.
    @MainActor
    func entities(matching string: String) async throws -> [ItemAppEntity] {
        let container = try IntentDependencies.make()
        let matches = try await container.itemRepository.search(query: string)
        guard let best = Self.bestMatch(for: string, in: matches) else { return [] }
        return [ItemAppEntity(id: best.id, name: best.name, locationDescription: best.locationDescription)]
    }

    /// Ranks `search(query:)`'s results by how specifically each one
    /// matched, rather than trusting its unordered pass/fail filter. Every
    /// item here already matched *something* -- `search` only returns hits
    /// -- so this just distinguishes a hit on the item's own name (strong
    /// signal) from one buried in its location, notes, or category (weak,
    /// coincidental). Ties fall back to whichever was touched most
    /// recently, the same tie-break `search(query:)` itself uses.
    private static func bestMatch(for query: String, in items: [StoredItem]) -> StoredItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items.first }

        func score(_ item: StoredItem) -> Int {
            let name = item.name.lowercased()
            if name == trimmed { return 4 }
            if name.contains(trimmed) { return 3 }
            if item.locationDescription.lowercased().contains(trimmed) { return 2 }
            if let notes = item.notes, notes.lowercased().contains(trimmed) { return 1 }
            if item.category.displayName.lowercased().contains(trimmed) { return 1 }
            return 0
        }

        return items
            .map { (item: $0, score: score($0)) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.item.updatedAt > $1.item.updatedAt }
            .first?.item
    }
}
