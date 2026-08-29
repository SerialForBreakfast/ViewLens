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
    func testNVJ1UnderstandsScreenWithoutUsingCanvas() throws {
        let app = launchApp(fixture: "nonvisual")
        navigate(to: "2", screen: "screen.aiReview", in: app)
        app.typeKey("2", modifierFlags: .command)

        XCTAssertTrue(element("review.nonvisualOutline", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("outline.screen", in: app).exists)
        let summary = element("outline.summary", in: app)
        XCTAssertTrue(summary.exists)
        XCTAssertTrue((summary.value as? String)?.contains("4 elements") == true)
        XCTAssertTrue(element("outline.region.region:login-form", in: app).exists)
        XCTAssertTrue(element("outline.element.element:heading", in: app).exists)
        XCTAssertTrue(element("outline.element.element:email", in: app).exists)
        XCTAssertFalse(element("review.canvas", in: app).exists, "Outline-only journey must not require the image canvas")
    }

    @MainActor
    func testNVJ2KeyboardSelectionSynchronizesOutlineCanvasAndFindings() throws {
        let app = launchApp(fixture: "nonvisual")
        navigate(to: "2", screen: "screen.aiReview", in: app)
        app.typeKey("3", modifierFlags: .command)

        XCTAssertTrue(element("outline.mismatches", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("outline.mismatch.mismatch:missing_accessible_name:element:email", in: app).exists)
        XCTAssertTrue(element("outline.mismatch.mismatch:missing_semantic_counterpart:element:submit", in: app).exists)
        XCTAssertTrue(element("outline.mismatch.mismatch:missing_visual_counterpart:element:legacy-action", in: app).exists)

        app.typeKey("]", modifierFlags: .command)
        app.typeKey("]", modifierFlags: .command)
        XCTAssertTrue(element("outline.element.element:email", in: app).isSelected)
        XCTAssertTrue(element("review.canvas.element.1", in: app).isSelected)

        app.typeKey("]", modifierFlags: [.command, .shift])
        let findingID = "outline.finding.FixtureMissingEmailName|missingAccessibilityLabel|WCAG 4.1.2|0"
        XCTAssertTrue(element(findingID, in: app).isSelected)
        XCTAssertTrue(element("review.canvas.element.1", in: app).isSelected)
    }

    @MainActor
    func testNVJ3ExposesTraversalEvidenceAndManualVerificationBoundary() throws {
        let app = launchApp(fixture: "nonvisual")
        navigate(to: "2", screen: "screen.aiReview", in: app)
        app.typeKey("2", modifierFlags: .command)

        XCTAssertTrue(element("outline.navigation", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("outline.navigation.reading_order", in: app).exists)
        let predicted = element("outline.navigation.predicted_voiceover", in: app)
        XCTAssertTrue(predicted.exists)
        XCTAssertTrue((predicted.value as? String)?.contains("manual VoiceOver verification is required") == true)
        XCTAssertTrue(element("outline.mismatch.mismatch:reading_order_divergence", in: app).exists)
    }

    @MainActor
    func testNVJ4ProvidesTextualSemanticAndVisualComparison() throws {
        let app = launchApp(fixture: "nonvisual")
        navigate(to: "4", screen: "screen.history", in: app)

        let compare = app.buttons["history.compare"]
        XCTAssertTrue(compare.waitForExistence(timeout: 5))
        XCTAssertTrue(compare.isEnabled)
        compare.click()

        XCTAssertTrue(element("comparison.sheet", in: app).waitForExistence(timeout: 5))
        let semantic = element("comparison.semanticDiff", in: app)
        let visual = element("comparison.visualDiffNarrative", in: app)
        XCTAssertTrue(semantic.exists)
        XCTAssertTrue(visual.exists)
        XCTAssertTrue((visual.value as? String)?.contains("Pixel changes") == true || (visual.value as? String)?.contains("material pixel change") == true)
    }

    @MainActor
    func testNonvisualJourneyAtMinimumWindowWithDeclaredAccommodationMatrix() throws {
        // These launch contexts verify deterministic layout and accessibility-tree parity.
        // Real system accommodations remain in the manual VoiceOver verification matrix.
        let accommodationSets = [
            "increase-contrast",
            "reduce-motion",
            "differentiate-without-color"
        ]
        for accommodation in accommodationSets {
            let app = launchApp(fixture: "nonvisual", accommodations: accommodation, minimumWindow: true)
            navigate(to: "2", screen: "screen.aiReview", in: app)
            app.typeKey("2", modifierFlags: .command)

            let root = element("app.root", in: app)
            XCTAssertTrue(root.waitForExistence(timeout: 5))
            XCTAssertTrue((root.value as? String)?.contains(accommodation) == true)
            XCTAssertTrue(element("outline.summary", in: app).exists)
            XCTAssertTrue(element("outline.navigation", in: app).exists)
            let windowSize = app.windows.firstMatch.frame.size
            XCTAssertLessThanOrEqual(windowSize.width, 950)
            XCTAssertLessThanOrEqual(windowSize.height, 720)
            app.terminate()
        }
    }

    @MainActor
    private func launchApp(
        fixture: String = "completed",
        accommodations: String? = nil,
        minimumWindow: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["VIEWLENS_UI_TESTING"] = "1"
        app.launchEnvironment["VIEWLENS_UI_FIXTURE"] = fixture
        if let accommodations { app.launchEnvironment["VIEWLENS_UI_ACCOMMODATIONS"] = accommodations }
        if minimumWindow { app.launchEnvironment["VIEWLENS_UI_WINDOW"] = "minimum" }
        app.launch()
        return app
    }

    @MainActor
    private func navigate(to key: String, screen identifier: String, in app: XCUIApplication) {
        app.typeKey(key, modifierFlags: [.command, .option])
        XCTAssertTrue(screen(identifier, in: app).waitForExistence(timeout: 5), "Expected \(identifier) after Command-\(key)")
    }

    @MainActor
    private func screen(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
