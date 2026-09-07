//
//  OnboardingFlowUITests.swift
//  LastPlaceUITests
//
//  Walks all three `OnboardingPage.defaultPages` via the primary button
//  (labeled "Continue" until the last page, then "Get Started" -- see
//  `OnboardingViewModel.primaryButtonTitle`) and confirms finishing lands on
//  the sign-in screen, since this launches signed out.
//

import XCTest

final class OnboardingFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_advancingThroughAllPages_thenFinishing_reachesAuthScreen() throws {
        let app = XCUIApplication.launchedForUITesting(showOnboarding: true)

        XCTAssertTrue(app.staticTexts["Save where things were last seen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Skip"].exists, "Skip should be offered on every page but the last")

        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Find anything in seconds"].waitForExistence(timeout: 5))

        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Everything stays on your device"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Skip"].exists, "The last page has nothing left to skip")

        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))
    }

    @MainActor
    func test_skip_fromFirstPage_reachesAuthScreen() throws {
        let app = XCUIApplication.launchedForUITesting(showOnboarding: true)

        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 10))
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))
    }
}
