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
import RevenueCat

@Observable
@MainActor
final class AppCoordinator {
    private(set) var flow: AppFlow = .splash

    private let container: AppDependencyContainer

    /// Set by `MainTabView` once its coordinators exist. Fired after a sync
    /// that followed a local wipe, so the tabs reload against the newly
    /// pulled data instead of the empty store they mounted against.
    /// Same decoupling rationale as `SettingsCoordinator.onAllDataDeleted`.
    @ObservationIgnored
    var onLocalDataReplaced: (() -> Void)?

    init(container: AppDependencyContainer) {
        self.container = container
    }

    /// Runs at app launch. Enforces a minimum splash duration so the transition
    /// doesn't feel like a flash, then decides between onboarding, requiring
    /// sign-in, the lock screen, and main.
    func start() async {
        let minimumDuration = container.configuration.splashMinimumDuration
        let deadline = Date().addingTimeInterval(minimumDuration)

        let hasOnboarded = await container.onboardingPreferences.hasCompletedOnboarding()
        let currentUser = await container.authService.currentUser

        let remaining = deadline.timeIntervalSinceNow
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        guard hasOnboarded else {
            flow = .onboarding
            return
        }
        guard let currentUser else {
            flow = .authRequired
            return
        }
        // Also checked here, not just in `completeSignIn`: a session can be
        // restored on launch without going through the sign-in screen at
        // all. Again this must complete before `flow` mounts the tabs, or
        // Home renders the previous account's data and never reloads.
        await prepareLocalStore(for: currentUser.id)
        // Same reasoning as `prepareLocalStore` above -- a restored session
        // never goes through `completeSignIn`, so this is the only place a
        // launch-time restore ties RevenueCat to the right account.
        await syncRevenueCatUser(currentUser.id)
        flow = shouldLock ? .locked : .main
        // A returning, already-signed-in user -- (re)register for remote
        // notifications on every launch, not just the first sign-in, so a
        // rotated/expired APNs token gets refreshed. No-ops quickly if
        // permission was already denied; see
        // `PushNotificationPermissionService`'s doc comment.
        Task {
            await container.pushNotificationPermissionService.requestAuthorizationAndRegisterIfNeeded()
            // Covers the launch-with-existing-session case: the token may
            // have arrived before this ran, or may arrive shortly after via
            // `MessagingDelegate` -- whichever wins, the row ends up
            // registered.
            await registerPushTokenIfAvailable()
        }
    }

    func completeOnboarding() {
        Task {
            await container.onboardingPreferences.setHasCompletedOnboarding(true)
            flow = .authRequired
        }
    }

    /// Called from `AuthView`'s `onAuthenticated` closure once sign-in/up
    /// succeeds. Goes through the same lock-or-main decision `start()`
    /// makes, then kicks off an initial sync -- for a first-time sign-in
    /// this is also what uploads whatever the person already had stored
    /// locally (see `SyncStatus`'s doc comment on why no separate
    /// migration step was needed).
    func completeSignIn() {
        Task {
            guard let user = await container.authService.currentUser else {
                flow = .authRequired
                return
            }

            // Wipe *before* `flow` changes, not after. Setting `.main`
            // mounts `MainTabView`, and `HomeView`'s `.task` reads
            // SwiftData immediately -- so doing this the other way round
            // meant Home loaded and displayed the previous account's rooms
            // before the wipe had even started, then never reloaded. The
            // wipe is local-only and fast, so gating the transition on it
            // costs nothing perceptible.
            await prepareLocalStore(for: user.id)
            await syncRevenueCatUser(user.id)
            flow = shouldLock ? .locked : .main

            try? await container.syncEngine.sync(userID: user.id, imageStorage: container.imageStorage)
            // Home mounted against an empty store; this is what makes the
            // pulled-down data actually appear.
            onLocalDataReplaced?()
        }
        Task {
            // Permission first: on a first run this is what triggers APNs
            // registration and therefore the FCM token. On every later
            // sign-in permission is already settled and this returns
            // immediately, leaving the retained token to be re-registered
            // against the account that just signed in.
            await container.pushNotificationPermissionService.requestAuthorizationAndRegisterIfNeeded()
            await registerPushTokenIfAvailable()
        }
    }

    /// Clears the local store when the account signing in isn't the one it
    /// currently holds data for, *before* the UI mounts.
    ///
    /// `SyncEngine.sync` enforces the same rule and is the real safety net
    /// -- see the note there. This exists because Home would otherwise
    /// render the previous account's rooms and items in the window between
    /// mounting and the first sync completing, which on a slow connection
    /// is long enough to be seen. Wiping here makes that window empty
    /// instead of wrong.
    ///
    /// Both are idempotent, so whichever runs first simply makes the other
    /// a no-op.
    /// Registers this device's FCM token against the now-signed-in account.
    ///
    /// Needed because the two events are independent and almost always
    /// arrive in the wrong order. Firebase hands over the token once, early
    /// in app launch, when there may be no session at all --
    /// `SupabaseDeviceTokenService.registerToken` then throws
    /// `notAuthenticated` and `MainTabView` discards it with `try?`. Since
    /// `MessagingDelegate` won't fire again until the token actually
    /// rotates, nothing would ever retry, leaving `device_tokens` empty and
    /// the account silently unreachable by push.
    ///
    /// That's invisible until you sign out and back in: an install that was
    /// already signed in at launch registers fine, which is why push worked
    /// before the sign-out flow existed and stopped afterwards.
    ///
    /// Safe to call on every sign-in -- `registerToken` upserts on the
    /// token, so re-registering the same one only bumps `updated_at`, and
    /// re-registering after an account switch correctly reassigns the row
    /// to whoever is signed in now.
    private func registerPushTokenIfAvailable() async {
        guard let token = PushNotificationRelay.shared.currentFCMToken else { return }
        do {
            try await container.deviceTokenService.registerToken(token, platform: "ios")
        } catch {
            container.logger.error("Registering push token after sign-in failed", error: error, category: "notifications")
        }
    }

    /// Ties this device's RevenueCat customer record to the same account ID
    /// the `entitlements` table's `user_id` column uses, by logging in with
    /// it as RevenueCat's `appUserID` -- otherwise RevenueCat only knows this
    /// device by an anonymous ID it generated itself, and the webhook that
    /// writes `entitlements` after a purchase has nothing to match against.
    ///
    /// Called from both `start()` (a restored session) and `completeSignIn()`
    /// (a fresh one) -- whichever runs first for a given launch, `logIn` is
    /// idempotent for the same ID, so calling it again from the other path
    /// later is harmless.
    ///
    /// Best-effort, like `registerPushTokenIfAvailable` below: a failure here
    /// shouldn't block sign-in from completing. Worst case, a purchase made
    /// before this succeeds attaches to RevenueCat's anonymous ID instead of
    /// this account -- recoverable via `Purchases.shared.restorePurchases()`,
    /// same safety net a reinstall relies on.
    ///
    /// VERIFY-BEFORE-TRUST: written without a compiler available in this
    /// session, same caveat as `SupabaseAuthService`. `Purchases.shared
    /// .logIn(_:)` returning `(customerInfo: CustomerInfo, created: Bool)`
    /// and being `async throws` matches the RevenueCat SDK's documented
    /// async surface, but hasn't been built against the actual package
    /// target here -- confirm once Xcode has it.
    private func syncRevenueCatUser(_ userID: UUID) async {
        do {
            _ = try await Purchases.shared.logIn(userID.uuidString)
        } catch {
            container.logger.error("RevenueCat logIn failed", error: error, category: "entitlements")
        }
    }

    private func prepareLocalStore(for userID: UUID) async {
        // Same decision `sync` makes, deliberately shared rather than
        // reimplemented -- an earlier version had its own weaker copy of
        // the check here, which is the kind of drift that lets a bug hide
        // in one path while looking fixed in the other.
        await container.syncEngine.wipeLocalDataIfAccountChanged(
            userID: userID,
            imageStorage: container.imageStorage
        )
        // Deliberately not calling `LastSignedInUserStore.set` here -- that
        // belongs to `sync`, which is what actually replaces the wiped data
        // with this account's. Claiming ownership before the pull would
        // mean an interrupted launch left an empty store marked as fully
        // this user's, and nothing would re-wipe or re-fetch.
    }

    /// Called after Settings' account section has already signed the user out (or
    /// deleted their account) via `AuthService` directly -- this just
    /// reacts to that by sending the whole app back through the
    /// `.authRequired` gate.
    /// Called after Settings' account section has already ended the session. Clears the
    /// local store on the way out so the signed-out device holds nothing.
    ///
    /// The data isn't lost: everything here has been pushed to Postgres, so
    /// signing back in re-downloads it on the first sync. The tradeoff is
    /// that returning to your own account now costs a network round trip
    /// instead of being instant -- accepted deliberately, since leaving a
    /// household inventory readable on a signed-out phone is the worse
    /// outcome.
    ///
    /// Ordering matters: `flow` moves first so the UI is already off the
    /// main tabs before rows start disappearing underneath it.
    func signOut() {
        flow = .authRequired
        Task {
            await container.syncEngine.wipeLocalData(imageStorage: container.imageStorage)
            // Resets RevenueCat back to a fresh anonymous ID, mirroring the
            // local wipe above -- without this, the *next* person to sign
            // in on this device would inherit whatever `appUserID` the
            // previous account left logged in, and a purchase made before
            // their own `syncRevenueCatUser` call completed would attach to
            // the wrong account. Best-effort, same reasoning as
            // `syncRevenueCatUser`: a failure here just means this device's
            // RevenueCat ID stays as it was, which the next sign-in's
            // `logIn` call corrects anyway.
            do {
                _ = try await Purchases.shared.logOut()
            } catch {
                container.logger.error("RevenueCat logOut failed", error: error, category: "entitlements")
            }
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
