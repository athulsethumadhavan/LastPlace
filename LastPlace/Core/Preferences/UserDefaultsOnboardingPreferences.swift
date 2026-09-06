//
//  UserDefaultsOnboardingPreferences.swift
//  LastPlace
//

import Foundation

actor UserDefaultsOnboardingPreferences: OnboardingPreferences {
    private static let key = "com.lastplace.onboarding.completed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasCompletedOnboarding() async -> Bool {
        defaults.bool(forKey: Self.key)
    }

    func setHasCompletedOnboarding(_ value: Bool) async {
        defaults.set(value, forKey: Self.key)
    }
}
