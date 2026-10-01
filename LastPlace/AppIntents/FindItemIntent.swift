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
//  was true at resolution time.
//
//  Answers in place by default — `openAppWhenRun` is deliberately `false`,
//  same as before, so a plain "find X" doesn't yank the person out of
//  whatever they were doing just to speak back a location. Setting it to
//  `true` was tried and reverted: it forced an immediate interrupt that
//  fought with Siri's own result bubble and produced a visible double
//  dialog, and that approach also only covers "runs" (voice), not "tapped"
//  (the actual gesture a result card's tap already is).
//
//  Tapping the result card is a separate, explicit gesture, and iOS already
//  opens the host app on that tap regardless of `openAppWhenRun` -- that
//  flag only controls whether *running* the intent forces the app forward
//  automatically. So the one thing this still needs to do itself is make
//  sure that whenever the app *does* open next, it lands on this item
//  rather than wherever it was last left.
//
//  That hand-off reuses `PushNotificationRelay` exactly as a tapped push
//  notification does — see `PushNotificationDestination` and
//  `MainTabCoordinator.open(_:)`. It's a deliberate reuse, not a new
//  mechanism: queuing this before `MainTabCoordinator` exists yet (the app
//  not already running when the result is tapped) is exactly the race the
//  relay's buffer-until-`flushPending()` design was built to solve for a
//  cold launch from a notification tap.
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

        // Queue the destination for whenever the app next opens -- most
        // likely from tapping this very result card. See the header
        // comment for why this doesn't also force the app open itself.
        PushNotificationRelay.shared.notificationTapped(.item(id: freshItem.id))

        let room = try? await container.roomRepository.fetchRoom(roomID: freshItem.roomID)
        if let roomName = room?.name {
            return .result(dialog: "\(freshItem.name) is in the \(roomName) — \(freshItem.locationDescription).")
        }
        return .result(dialog: "\(freshItem.name) is at \(freshItem.locationDescription).")
    }
}
