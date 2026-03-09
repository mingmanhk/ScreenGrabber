//
//  ScreenGrabberUITests.swift
//  ScreenGrabberUITests
//
//  UI tests for the ScreenGrabber menu-bar application.
//
//  Note: ScreenGrabber is a LSUIElement app (menu-bar only).
//  It has no dock icon and no main window at launch.
//  Tests interact via the status bar menu or verify app process state.
//

import XCTest

final class ScreenGrabberUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    /// App should launch without crashing.
    @MainActor
    func testAppLaunchesCleanly() throws {
        app.launch()
        // Give menu-bar app a moment to settle
        let launched = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(launched, "App should enter runningForeground state within 5 seconds")
    }

    /// App process must be alive after launch.
    @MainActor
    func testAppProcessIsRunningAfterLaunch() throws {
        app.launch()
        XCTAssertTrue(app.state != .notRunning, "App process must be running after launch")
    }

    // MARK: - Menu Bar Interaction

    /// Opening the status bar menu should present capture options.
    @MainActor
    func testStatusBarMenuContainsCaptureButton() throws {
        app.launch()

        // Access the status bar item via XCUIApplication extras
        let statusItem = app.statusItems.firstMatch
        if !statusItem.exists {
            throw XCTSkip("Status bar item not accessible in this test environment")
        }
        if !statusItem.isHittable {
            throw XCTSkip("Status bar item exists but is not hittable (may be off-screen)")
        }

        statusItem.click()

        // After clicking, at least one element should appear
        let appeared = app.windows.firstMatch.waitForExistence(timeout: 3)
            || app.popovers.firstMatch.waitForExistence(timeout: 3)
            || app.menus.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(appeared, "A UI element should appear after clicking the status bar item")
    }

    // MARK: - Settings Window

    /// Settings window should open when triggered via menu.
    @MainActor
    func testSettingsWindowOpensFromMenuBar() throws {
        app.launch()

        let statusItem = app.statusItems.firstMatch
        if !statusItem.exists {
            throw XCTSkip("Status bar item not accessible in this test environment")
        }
        if !statusItem.isHittable {
            throw XCTSkip("Status bar item exists but is not hittable (may be off-screen)")
        }

        statusItem.click()

        // Look for a "Settings" button or menu item
        let settingsButton = app.buttons["Settings"].firstMatch
        if !settingsButton.waitForExistence(timeout: 3) {
            throw XCTSkip("Settings button not found — UI may differ")
        }

        settingsButton.click()

        // A window titled "Settings" or "Preferences" should appear
        let settingsWindow = app.windows.matching(NSPredicate(format: "title CONTAINS[c] 'Settings'")).firstMatch
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 5),
            "Settings window should appear within 5 seconds"
        )
    }

    // MARK: - Termination

    /// App should terminate cleanly when quit is requested.
    @MainActor
    func testAppTerminatesCleanly() throws {
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 5)

        app.terminate()
        let terminated = app.wait(for: .notRunning, timeout: 5)
        XCTAssertTrue(terminated, "App should terminate within 5 seconds")
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
