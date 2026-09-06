//
//  AddChecklistEntryIntent.swift
//  LastPlace
//
//  "Hey Siri, add sunglasses to my checklist in LastPlace." Wraps
//  `AddChecklistEntryUseCase` the same way the in-app "Add item" screen's
//  `addLinked(item:)` path does — as a linked entry pointing at a real
//  `StoredItem`, not free text. That's a deliberate change from the first
//  pass at this intent (which took a plain `itemName: String`): App
//  Intents' shortcut-phrase validator only allows `AppEntity`/`AppEnum`
//  parameters inside a spoken phrase, and linking to a real item is also the
//  better outcome anyway — the checklist entry shows the item's live
//  location instead of whatever text Siri happened to transcribe.
//

import AppIntents
import Foundation

struct AddChecklistEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Checklist"
    static var description = IntentDescription(
        "Adds a saved item to one of your LastPlace checklists.",
        categoryName: "Checklists"
    )
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    @Parameter(title: "Checklist")
    var checklist: ChecklistAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$item) to \(\.$checklist)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentDependencies.make()

        do {
            let existingEntries = try await container.checklistRepository.fetchEntries(checklistID: checklist.id)
            let addEntryUseCase = DefaultAddChecklistEntryUseCase(checklistRepository: container.checklistRepository)
            _ = try await addEntryUseCase.execute(
                AddChecklistEntryInput(
                    checklistID: checklist.id,
                    title: item.name,
                    linkedItemID: item.id,
                    sortOrder: existingEntries.count
                )
            )
        } catch RepositoryError.notFound {
            return .result(dialog: "I couldn't find that checklist anymore — it may have been deleted.")
        } catch {
            container.logger.error("Siri add-checklist-entry intent failed", error: error, category: "app-intents")
            return .result(dialog: "Something went wrong adding \(item.name) to \(checklist.name).")
        }

        return .result(dialog: "Added \(item.name) to \(checklist.name).")
    }
}
