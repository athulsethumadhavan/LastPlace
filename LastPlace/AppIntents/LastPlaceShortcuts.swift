//
//  LastPlaceShortcuts.swift
//  LastPlace
//
//  Declares the phrases that get these intents automatically surfaced by
//  Siri, Spotlight, and the Shortcuts app without the user having to build
//  their own automation first. Every phrase must include `.applicationName`
//  per App Intents' requirement, so "LastPlace" is always part of what's
//  spoken.
//
//  Two constraints shaped these phrases, both enforced by the App Intents
//  build-time validator rather than being a style choice: a phrase can only
//  capture one parameter from speech, and that parameter has to be an
//  `AppEntity`/`AppEnum` type — plain `String` isn't allowed. That's why
//  `AddChecklistEntryIntent`'s phrases only reference `\.$item`; `checklist`
//  is still a required parameter, it's just resolved through Siri's
//  automatic follow-up ("Which checklist?") instead of being spoken in the
//  same sentence.
//

import AppIntents

struct LastPlaceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindItemIntent(),
            phrases: [
                "Find \(\.$item) in \(.applicationName)",
                "Where is \(\.$item) in \(.applicationName)",
                "Where did I put \(\.$item) in \(.applicationName)"
            ],
            shortTitle: "Find Item",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: AddChecklistEntryIntent(),
            phrases: [
                "Add \(\.$item) to my checklist in \(.applicationName)",
                "Add \(\.$item) to a checklist in \(.applicationName)"
            ],
            shortTitle: "Add to Checklist",
            systemImageName: "checklist"
        )
    }
}
