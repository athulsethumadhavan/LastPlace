//
//  SearchUITests.swift
//  LastPlaceUITests
//

import XCTest

final class SearchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_freshInstall_showsEmptyState() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        XCTAssertTrue(app.tabBars.buttons["Search"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Search"].tap()

        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 10))
    }

    @MainActor
    func test_typingAQuery_showsCancelButtonAndNoMatchesMessage() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)
        app.tabBars.buttons["Search"].tap()

        let searchField = app.textFields["Search items, rooms, or locations"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("keys")

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        // Nothing has ever been saved on a fresh in-memory store, so any
        // query -- however plausible -- comes back with no matches.
        XCTAssertTrue(app.staticTexts["No matches for \u{201C}keys\u{201D}"].waitForExistence(timeout: 5))

        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["Cancel"].exists)
        XCTAssertEqual(searchField.value as? String, "Search items, rooms, or locations")
    }
}
