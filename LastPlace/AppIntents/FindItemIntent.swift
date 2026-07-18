//
//  FindItemIntent.swift
//  LastPlace
//
//  "Hey Siri, find my passport in LastPlace." The item is an `ItemAppEntity`
//  rather than free text — App Intents' shortcut-phrase validator only
//  allows `AppEntity`/`AppEnum` parameters in a spoken phrase, and Siri
//  resolves the spoken name against real saved items via
//  `ItemEntityQuery.entities(matching:)` before `perform()` ever runs, so
//  this re-fetches by id for a live location rather than trusting whatever
//  was true at resolution time. Runs entirely in the background — no need
//  to open the app just to speak back a location.
//

import AppIntents
import Foundation

struct FindItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Item"
    static var description = IntentDescription(
        "Finds where a saved item is stored in LastPlace.",
        categoryName: "Search"
    )
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$item) in LastPlace")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentDependencies.make()

        let freshItem: StoredItem
        do {
            freshItem = try await container.itemRepository.fetchItem(itemID: item.id)
        } catch {
            return .result(dialog: "I couldn't find \(item.name) anymore — it may have been deleted.")
        }

        let room = try? await container.roomRepository.fetchRoom(roomID: freshItem.roomID)
        if let roomName = room?.name {
            return .result(dialog: "\(freshItem.name) is in the \(roomName) — \(freshItem.locationDescription).")
        }
        return .result(dialog: "\(freshItem.name) is at \(freshItem.locationDescription).")
    }
}
