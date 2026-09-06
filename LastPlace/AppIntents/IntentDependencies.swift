//
//  IntentDependencies.swift
//  LastPlace
//
//  App Intents are instantiated directly by the system — Siri, Shortcuts,
//  Spotlight — never through our own view hierarchy, so they can't reach the
//  already-running app's `AppDependencyContainer` via normal SwiftUI
//  environment injection the way every other feature does.
//
//  Each intent invocation instead builds its own container through the same
//  `AppDependencyContainer.makeDefault()` composition-root factory the app
//  itself calls at launch. That keeps this from becoming the singleton the
//  container's own doc comment warns against: it's still the one production
//  factory, just invoked once per short-lived, stateless intent run instead
//  of once per app launch. SwiftData supports multiple `ModelContainer`s
//  pointed at the same on-disk store, so this is safe to do concurrently
//  with the main app process.
//

import Foundation

@MainActor
enum IntentDependencies {
    static func make() throws -> AppDependencyContainer {
        try AppDependencyContainer.makeDefault()
    }
}
