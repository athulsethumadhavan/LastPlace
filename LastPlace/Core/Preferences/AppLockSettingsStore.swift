//
//  AppLockSettingsStore.swift
//  LastPlace
//
//  Same shape as `AppearanceSettingsStore` — `@Observable` + `@MainActor`
//  wrapping a single `UserDefaults`-backed flag, injected through the
//  container. `AppCoordinator` reads `isEnabled` at launch/foreground to
//  decide whether to show the lock screen; the Security settings screen
//  writes it.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppLockSettingsStore {
    private static let key = "com.lastplace.applock.enabled"

    private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Self.key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.key)
    }
}
