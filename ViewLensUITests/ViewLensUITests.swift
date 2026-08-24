import XCTest

final class ViewLensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunnerHandshake() {
        XCTAssertTrue(true)
    }

    @MainActor
    func testPrimaryNavigationAndKeyboardShortcuts() throws {
        let app = launchApp()
        XCTAssertTrue(screen("screen.currentStatus", in: app).waitForExistence(timeout: 8))

        navigate(to: "2", screen: "screen.aiReview", in: app)
        navigate(to: "3", screen: "screen.playground", in: app)
        navigate(to: "4", screen: "screen.history", in: app)
        navigate(to: "5", screen: "screen.settings", in: app)
        navigate(to: "1", screen: "screen.currentStatus", in: app)
    }

    @MainActor
    func testImportDialogCanBeOpenedAndCancelledFromKeyboard() throws {
        let app = launchApp()
        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(screen("screen.currentStatus", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testFindingSearchCanvasNavigationAndExport() throws {
        let app = launchApp()
        navigate(to: "2", screen: "screen.aiReview", in: app)

        let search = app.textFields["findings.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click(); search.typeText("does-not-match")
        XCTAssertTrue(app.staticTexts["No Matching Findings"].waitForExistence(timeout: 3))
        search.typeKey("a", modifierFlags: .command); search.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.descendants(matching: .any)["finding.card"].firstMatch.waitForExistence(timeout: 3))

        let canvas = app.descendants(matching: .any)["review.canvas"].firstMatch
        XCTAssertTrue(canvas.exists)
        canvas.click(); canvas.typeKey(.rightArrow, modifierFlags: []); canvas.typeKey(.escape, modifierFlags: [])

        let export = app.buttons["review.export"]
        XCTAssertTrue(export.exists); export.click()
        let json = app.menuItems["JSON Report"]
        XCTAssertTrue(json.waitForExistence(timeout: 3)); json.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testHistorySelectionReopensSharedReview() throws {
        let app = launchApp()
        navigate(to: "4", screen: "screen.history", in: app)
        let review = app.staticTexts["LoginForm"].firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.doubleClick()
        XCTAssertTrue(screen("screen.aiReview", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LoginForm [UI Test Fixture]"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCancellationRequiresConfirmationAndDefinesCancelledState() throws {
        let app = launchApp(fixture: "running")
        navigate(to: "2", screen: "screen.aiReview", in: app)
        let cancel = app.buttons["review.cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.click()
        let confirm = app.buttons["Cancel Review"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3)); confirm.click()
        XCTAssertTrue(app.staticTexts["Review cancelled"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPlaygroundExposesExplicitModesAndRunAction() throws {
        let app = launchApp()
        navigate(to: "3", screen: "screen.playground", in: app)
        XCTAssertTrue(app.buttons["Import File"].waitForExistence(timeout: 3))
        app.buttons["Template"].click()
        XCTAssertTrue(app.buttons["playground.run"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'matrix contains'")).firstMatch.exists)
    }

    @MainActor
    private func launchApp(fixture: String = "completed") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["VIEWLENS_UI_TESTING"] = "1"
        app.launchEnvironment["VIEWLENS_UI_FIXTURE"] = fixture
        app.launch()
        return app
    }

    @MainActor
    private func navigate(to key: String, screen identifier: String, in app: XCUIApplication) {
        app.typeKey(key, modifierFlags: .command)
        XCTAssertTrue(screen(identifier, in: app).waitForExistence(timeout: 5), "Expected \(identifier) after Command-\(key)")
    }

    @MainActor
    private func screen(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
