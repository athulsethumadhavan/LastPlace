//
//  SettingsNavigationUITests.swift
//  LastPlaceUITests
//

import XCTest

final class SettingsNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openSettingsTab(on app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
    }

    @MainActor
    func test_settingsRoot_listsEveryRow() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        openSettingsTab(on: app)

        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Permissions"].exists)
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        XCTAssertTrue(app.staticTexts["Security"].exists)
        XCTAssertTrue(app.staticTexts["Data Management"].exists)
        XCTAssertTrue(app.staticTexts["Shared Rooms"].exists)
        XCTAssertTrue(app.staticTexts["Gifts"].exists)
        XCTAssertTrue(app.buttons["Sign Out"].exists)
        XCTAssertTrue(app.buttons["Delete Account"].exists)
    }

    @MainActor
    func test_navigatingToSecurityAndBack_returnsToSettingsRoot() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        openSettingsTab(on: app)

        XCTAssertTrue(app.staticTexts["Security"].waitForExistence(timeout: 10))
        app.staticTexts["Security"].tap()

        // `SecurityView` uses the app's custom `AppNavBar` rather than the
        // system nav bar, so its title is a plain static text, and its back
        // button is the screen's only (unlabeled) circular icon button.
        XCTAssertTrue(app.staticTexts["Security"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Data Management"].exists, "Should have left the Settings root list")

        app.buttons.firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Data Management"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_deleteAccount_showsConfirmationDialogWithCancel() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        openSettingsTab(on: app)

        XCTAssertTrue(app.buttons["Delete Account"].waitForExistence(timeout: 10))
        app.buttons["Delete Account"].tap()

        XCTAssertTrue(app.staticTexts["Delete your account?"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        // Cancelling must not have signed the account out.
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 5))
    }
}
