//
//  InMemoryOnboardingPreferences.swift
//  LastPlace
//
//  Preview / test double.
//

import Foundation

actor InMemoryOnboardingPreferences: OnboardingPreferences {
    private var completed: Bool

    init(completed: Bool = false) {
        self.completed = completed
    }

    func hasCompletedOnboarding() async -> Bool { completed }
    func setHasCompletedOnboarding(_ value: Bool) async { completed = value }
}
