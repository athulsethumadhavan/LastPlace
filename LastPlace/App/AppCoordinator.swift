//
//  AppCoordinator.swift
//  LastPlace
//
//  Root coordinator. Owns the top-level flow enum and mediates between the
//  splash → onboarding → main hand-offs. Feature-level navigation lives inside
//  each feature's own coordinator.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppCoordinator {
    private(set) var flow: AppFlow = .splash

    private let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
    }

    /// Runs at app launch. Enforces a minimum splash duration so the transition
    /// doesn't feel like a flash, then decides between onboarding and main.
    func start() async {
        let minimumDuration = container.configuration.splashMinimumDuration
        let deadline = Date().addingTimeInterval(minimumDuration)

        let hasOnboarded = await container.onboardingPreferences.hasCompletedOnboarding()

        let remaining = deadline.timeIntervalSinceNow
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        flow = hasOnboarded ? .main : .onboarding
    }

    func completeOnboarding() {
        Task {
            await container.onboardingPreferences.setHasCompletedOnboarding(true)
            flow = .main
        }
    }

    func resetOnboarding() {
        Task {
            await container.onboardingPreferences.setHasCompletedOnboarding(false)
            flow = .onboarding
        }
    }
}
