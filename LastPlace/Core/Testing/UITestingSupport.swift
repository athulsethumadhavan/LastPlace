//
//  UITestingSupport.swift
//  LastPlace
//
//  Lets `LastPlaceUITests` launch the app against an in-memory, fully-mocked
//  `AppDependencyContainer` instead of the real disk-backed one -- so UI
//  tests are deterministic (no real Supabase network calls, no state left
//  over from a previous run) and can jump straight past onboarding/sign-in
//  when a test doesn't care about exercising those screens.
//
//  Only ever compiled into Debug builds, and only takes effect when the
//  launch arguments below are actually present -- a normal Debug build run
//  from Xcode without them behaves exactly like Release.
//

#if DEBUG
import Foundation

enum UITestingSupport {
    /// Set on `XCUIApplication().launchArguments` by every `LastPlaceUITests`
    /// case that needs a deterministic container. Its mere presence is the
    /// switch; the other two flags only matter once this one is set.
    private static let uiTestingFlag = "-uiTesting"
    /// When present, the container starts already signed in (see
    /// `AppDependencyContainer.makeUITesting`), so a test can jump straight
    /// to the main flow instead of walking through sign-in every launch.
    private static let signedInFlag = "-uiTestingSignedIn"
    /// When present, onboarding has NOT been completed -- the inverse of
    /// `makePreview`'s `onboardingCompleted`, spelled as a "show" flag
    /// because that's the more natural thing for a launch argument to ask
    /// for from the test's point of view.
    private static let showOnboardingFlag = "-uiTestingShowOnboarding"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingFlag)
    }

    /// `nil` when `-uiTesting` wasn't passed, so `AppBootstrap` can fall
    /// back to the real `makeDefault()` container untouched.
    @MainActor
    static func makeContainerIfNeeded() -> AppDependencyContainer? {
        guard isUITesting else { return nil }

        let arguments = ProcessInfo.processInfo.arguments
        let signedIn = arguments.contains(signedInFlag)
        let showOnboarding = arguments.contains(showOnboardingFlag)

        do {
            return try AppDependencyContainer.makeUITesting(
                signedIn: signedIn,
                onboardingCompleted: !showOnboarding
            )
        } catch {
            // A failure here means the in-memory ModelContainer itself
            // couldn't be built -- extremely unlikely, and there's no
            // sensible UI-testing fallback for it. Crashing loudly beats a
            // UI test silently exercising the real disk-backed container
            // instead of the deterministic one it asked for.
            fatalError("UI testing container failed to build: \(error)")
        }
    }
}

extension AppDependencyContainer {
    /// UI-testing wiring: the same in-memory, fully-mocked services as
    /// `makePreview()`, optionally starting already signed in.
    ///
    /// Rebuilds on top of `makePreview()` rather than duplicating its
    /// wiring, then swaps in a pre-seeded `MockAuthService` when
    /// `signedIn` is true -- everything else (repositories, image storage,
    /// the rest of the mocked services) stays exactly what `makePreview()`
    /// already hands out.
    static func makeUITesting(signedIn: Bool, onboardingCompleted: Bool) throws -> AppDependencyContainer {
        let base = try makePreview(onboardingCompleted: onboardingCompleted)
        guard signedIn else { return base }

        let signedInUser = AuthUser(id: UUID(), email: "uitest@lastplace.app", fullName: "UI Test")
        return AppDependencyContainer(
            configuration: base.configuration,
            modelContainer: base.modelContainer,
            imageStorage: base.imageStorage,
            objectDetection: base.objectDetection,
            aiItemIdentification: base.aiItemIdentification,
            logger: base.logger,
            onboardingPreferences: base.onboardingPreferences,
            appearanceSettings: base.appearanceSettings,
            appLockSettings: base.appLockSettings,
            biometricAuthenticator: base.biometricAuthenticator,
            authService: MockAuthService(user: signedInUser),
            roomSharingService: base.roomSharingService,
            itemGiftingService: base.itemGiftingService,
            deviceTokenService: base.deviceTokenService,
            pushNotificationPermissionService: base.pushNotificationPermissionService,
            entitlementService: base.entitlementService,
            analytics: base.analytics,
            homeRepository: base.homeRepository,
            roomRepository: base.roomRepository,
            itemRepository: base.itemRepository,
            snapshotRepository: base.snapshotRepository,
            scanRepository: base.scanRepository,
            checklistRepository: base.checklistRepository,
            makeCameraCapture: base.makeCameraCapture
        )
    }
}
#endif
