//
//  UITestLaunch.swift
//  LastPlaceUITests
//
//  Every UI test in this target launches against the deterministic,
//  in-memory container `UITestingSupport` builds (see that file's doc
//  comment in the app target) rather than the real disk-backed one --
//  no live Supabase calls, no state left over from a previous run, and a
//  fresh `ModelContainer` every launch. This centralizes the launch-argument
//  wiring so each test just states the state it wants to start from.
//

import XCTest

extension XCUIApplication {
    /// Launches the app against the UI-testing container.
    ///
    /// - Parameters:
    ///   - signedIn: Starts with a mocked, already-authenticated user when
    ///     `true` -- lets a test jump straight to the main tab flow instead
    ///     of walking through sign-in first.
    ///   - showOnboarding: Starts with onboarding NOT yet completed when
    ///     `true`, so the onboarding carousel is what appears first.
    @MainActor
    static func launchedForUITesting(signedIn: Bool = false, showOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uiTesting"]
        if signedIn { arguments.append("-uiTestingSignedIn") }
        if showOnboarding { arguments.append("-uiTestingShowOnboarding") }
        app.launchArguments = arguments
        app.launch()
        return app
    }
}
