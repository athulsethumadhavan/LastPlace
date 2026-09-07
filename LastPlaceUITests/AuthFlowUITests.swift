//
//  AuthFlowUITests.swift
//  LastPlaceUITests
//
//  Exercises `AuthView` against the UI-testing container's `MockAuthService`
//  (see `AppDependencyContainer.makePreview`), which accepts any well-formed
//  credentials -- there's no real Supabase account behind this, so these
//  tests cover the screen's own state machine (mode toggle, sign-in) rather
//  than real authentication.
//

import XCTest

final class AuthFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_toggleMode_revealsSignUpFieldsAndSwapsCopy() throws {
        let app = XCUIApplication.launchedForUITesting()

        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["authFullNameField"].exists)

        app.buttons["Sign Up"].tap()

        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["authFullNameField"].exists)
        XCTAssertTrue(app.secureTextFields["authConfirmPasswordField"].exists)
        XCTAssertTrue(app.buttons["Create Account"].exists)

        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_signIn_withValidCredentials_reachesMainTabs() throws {
        let app = XCUIApplication.launchedForUITesting()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))

        let emailField = app.textFields["authEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("person@example.com")

        let passwordField = app.secureTextFields["authPasswordField"]
        passwordField.tap()
        passwordField.typeText("password1")

        app.buttons["Sign In"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
    }

    @MainActor
    func test_signIn_submitButton_disabledUntilFieldsAreValid() throws {
        let app = XCUIApplication.launchedForUITesting()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))

        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists)
        XCTAssertFalse(signInButton.isEnabled, "Empty email/password shouldn't allow submitting")

        let emailField = app.textFields["authEmailField"]
        emailField.tap()
        emailField.typeText("person@example.com")
        let passwordField = app.secureTextFields["authPasswordField"]
        passwordField.tap()
        passwordField.typeText("password1")

        XCTAssertTrue(signInButton.isEnabled)
    }
}
