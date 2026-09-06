//
//  AppearanceSettingsStore.swift
//  LastPlace
//
//  Unlike `OnboardingPreferences` (an async actor-backed port checked once at
//  launch), appearance needs to drive `.preferredColorScheme` live across the
//  whole app the instant it changes in Settings. `@Observable` + `@MainActor`
//  gives SwiftUI that reactivity directly, so this skips the
//  protocol-plus-actor indirection in favor of a small owned store, injected
//  through the container like everything else.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppearanceSettingsStore {
    private static let key = "com.lastplace.appearance.mode"

    private let defaults: UserDefaults

    var mode: AppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            defaults.set(mode.rawValue, forKey: Self.key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key), let saved = AppearanceMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .system
        }
    }
}
