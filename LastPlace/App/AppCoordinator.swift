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
    /// doesn't feel like a flash, then decides between onboarding, the lock
    /// screen, and main.
    func start() async {
        let minimumDuration = container.configuration.splashMinimumDuration
        let deadline = Date().addingTimeInterval(minimumDuration)

        let hasOnboarded = await container.onboardingPreferences.hasCompletedOnboarding()

        let remaining = deadline.timeIntervalSinceNow
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        guard hasOnboarded else {
            flow = .onboarding
            return
        }
        flow = shouldLock ? .locked : .main
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

    // MARK: App lock

    /// What the device supports — the lock screen uses this to label its
    /// button ("Unlock with Face ID" vs "Unlock with Touch ID") and Security
    /// settings uses it to decide whether to offer the toggle at all.
    var biometryKind: BiometryKind {
        container.biometricAuthenticator.availableBiometry()
    }

    /// The setting is only honored if the device actually has biometry
    /// enrolled — if someone enables the toggle on a device that later loses
    /// biometry (e.g. Face ID gets disabled in system Settings), this falls
    /// back to leaving the app unlocked rather than stranding the user
    /// outside their own data.
    private var shouldLock: Bool {
        container.appLockSettings.isEnabled && biometryKind.isAvailable
    }

    /// Prompts biometric authentication and moves to `.main` on success.
    /// Returns the result so the lock screen can show a retry affordance on
    /// failure without duplicating the flow-transition logic.
    @discardableResult
    func unlock() async -> Bool {
        let success = await container.biometricAuthenticator.authenticate(
            reason: "Unlock LastPlace"
        )
        if success {
            flow = .main
        }
        return success
    }

    /// Called when the app leaves the foreground. Re-arms the lock screen so
    /// returning to the app (including from the app switcher) requires
    /// authenticating again, same as the launch-time check.
    func lockIfNeeded() {
        guard case .main = flow, shouldLock else { return }
        flow = .locked
    }
}
