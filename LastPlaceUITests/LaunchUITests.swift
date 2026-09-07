//
//  LaunchUITests.swift
//  LastPlaceUITests
//
//  Smoke tests confirming the app reaches a stable screen from a cold
//  launch in each of the three states `AppCoordinator` gates on: signed
//  out (post-onboarding), and signed in. Deeper coverage of each
//  destination screen lives in its own test file.
//

import XCTest

final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_launch_signedOut_reachesAuthScreen() throws {
        let app = XCUIApplication.launchedForUITesting()

        // `AuthMode.signIn.headline` -- see `AuthViewModel.swift`.
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Sign In"].exists)
    }

    @MainActor
    func test_launch_signedIn_reachesMainTabs() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Search"].exists)
        XCTAssertTrue(app.tabBars.buttons["Checklists"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    @MainActor
    func test_launch_showingOnboarding_reachesFirstOnboardingPage() throws {
        let app = XCUIApplication.launchedForUITesting(showOnboarding: true)

        // First of `OnboardingPage.defaultPages`.
        XCTAssertTrue(app.staticTexts["Save where things were last seen"].waitForExistence(timeout: 10))
    }
}
