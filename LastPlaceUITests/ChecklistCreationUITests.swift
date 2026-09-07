//
//  ChecklistCreationUITests.swift
//  LastPlaceUITests
//

import XCTest

final class ChecklistCreationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openChecklistsTab(on app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Checklists"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Checklists"].tap()
    }

    @MainActor
    func test_freshInstall_showsEmptyStateWithCreateChecklistCTA() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        openChecklistsTab(on: app)

        XCTAssertTrue(app.staticTexts["No checklists yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Create a checklist"].exists)
    }

    @MainActor
    func test_creatingAChecklist_withAPresetType_showsItInTheList() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        openChecklistsTab(on: app)

        XCTAssertTrue(app.buttons["Create a checklist"].waitForExistence(timeout: 10))
        app.buttons["Create a checklist"].tap()

        XCTAssertTrue(app.navigationBars["New Checklist"].waitForExistence(timeout: 5))

        let nameField = app.textFields["Checklist name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Ski Trip")

        // `CreateChecklistViewModel.presetTypes` defaults to `.work` --
        // explicitly picking "Travel" exercises the type picker itself
        // rather than relying on the default selection.
        app.buttons["Travel"].tap()

        let saveButton = app.buttons["Save checklist"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Ski Trip"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No checklists yet"].exists)
    }

    @MainActor
    func test_creatingAChecklist_withCustomType_requiresATypeName() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        openChecklistsTab(on: app)

        XCTAssertTrue(app.buttons["Create a checklist"].waitForExistence(timeout: 10))
        app.buttons["Create a checklist"].tap()

        let nameField = app.textFields["Checklist name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Camping")

        app.buttons["Custom"].tap()
        let saveButton = app.buttons["Save checklist"]
        XCTAssertFalse(saveButton.isEnabled, "A custom type needs its own name before saving is allowed")

        let customTypeField = app.textFields["Custom checklist type"]
        XCTAssertTrue(customTypeField.waitForExistence(timeout: 5))
        customTypeField.tap()
        customTypeField.typeText("Outdoors")

        XCTAssertTrue(saveButton.isEnabled)
    }
}
