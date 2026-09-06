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
//  (via `ItemEntityQuery`'s fuzzy matching) and can disambiguate rather than
//  taking a dictated string on faith.
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
    @MainActor
    func entities(matching string: String) async throws -> [ItemAppEntity] {
        let container = try IntentDependencies.make()
        let matches = try await container.itemRepository.search(query: string)
        return matches.map { ItemAppEntity(id: $0.id, name: $0.name, locationDescription: $0.locationDescription) }
    }
}
