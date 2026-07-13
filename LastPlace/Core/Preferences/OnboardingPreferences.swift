//
//  OnboardingPreferences.swift
//  LastPlace
//
//  Small `Sendable` port for whether the user has cleared the onboarding flow.
//  Kept minimal so tests and previews can inject an in-memory implementation.
//

import Foundation

protocol OnboardingPreferences: Sendable {
    func hasCompletedOnboarding() async -> Bool
    func setHasCompletedOnboarding(_ value: Bool) async
}
