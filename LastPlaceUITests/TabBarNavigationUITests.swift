//
//  TabBarNavigationUITests.swift
//  LastPlaceUITests
//
//  `MainTabView` uses a native `TabView`/`.tabItem` bar (see its doc
//  comment on why the custom `FloatingTabBar` was reverted), so each tab
//  is a standard, independently-selectable `tabBars.buttons` element with
//  its own `NavigationStack`.
//

import XCTest

final class TabBarNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_everyTab_isReachableAndBecomesSelected() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        for title in ["Home", "Search", "Checklists", "Settings", "Home"] {
            let tab = tabBar.buttons[title]
            XCTAssertTrue(tab.exists, "Expected a \(title) tab")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(title) should be selected after tapping it")
        }
    }

    @MainActor
    func test_switchingTabs_preservesEachTabsOwnNavigationState() throws {
        let app = XCUIApplication.launchedForUITesting(signedIn: true)

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No rooms yet"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Checklists"].tap()
        XCTAssertTrue(app.buttons["Create a checklist"].waitForExistence(timeout: 10))
        app.buttons["Create a checklist"].tap()
        XCTAssertTrue(app.navigationBars["New Checklist"].waitForExistence(timeout: 5))

        // Hopping away to another tab and back should not have reset the
        // Checklists tab's own navigation stack -- `New Checklist` should
        // still be on screen, per-tab `NavigationStack`s being independent.
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)

        app.tabBars.buttons["Checklists"].tap()
        XCTAssertTrue(app.navigationBars["New Checklist"].waitForExistence(timeout: 5))
    }
}
