//
//  HomeRoomCreationUITests.swift
//  LastPlaceUITests
//
//  A signed-in launch starts with an auto-created default home (see
//  `HomeRepository.fetchDefaultHome`'s doc comment) but no rooms, so Home
//  shows its empty state first. Covers creating the first room end-to-end
//  through `CreateRoomView`.
//

import XCTest

final class HomeRoomCreationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_freshInstall_showsEmptyStateWithCreateRoomCTA() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No rooms yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Create a room"].exists)
    }

    @MainActor
    func test_creatingARoom_fromEmptyState_showsItOnHome() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        XCTAssertTrue(app.buttons["Create a room"].waitForExistence(timeout: 10))
        app.buttons["Create a room"].tap()

        XCTAssertTrue(app.navigationBars["New Room"].waitForExistence(timeout: 5))

        let nameField = app.textFields["Room name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Living Room")

        let saveButton = app.buttons["Save room"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        // Back on Home, no longer empty -- the new room's card shows its name.
        XCTAssertTrue(app.staticTexts["Living Room"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No rooms yet"].exists)
    }

    @MainActor
    func test_createRoom_saveButton_disabledUntilNamed() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        XCTAssertTrue(app.buttons["Create a room"].waitForExistence(timeout: 10))
        app.buttons["Create a room"].tap()

        let saveButton = app.buttons["Save room"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertFalse(saveButton.isEnabled)
    }
}
