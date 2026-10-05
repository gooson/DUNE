@preconcurrency import XCTest

@MainActor
final class WellnessRegressionTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "wellness" }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToWellness()
    }

    func testCompareMetricsSharesPeriodAndDismisses() throws {
        XCTAssertTrue(app.waitAndTapToolbarAction("wellness-compare-metrics"),
                      "Wellness should expose metric comparison directly or in toolbar overflow\n\(app.debugDescription)")

        let firstPane = app.descendants(matching: .any)["metric-comparison-first"].firstMatch
        let secondPane = app.descendants(matching: .any)["metric-comparison-second"].firstMatch
        XCTAssertTrue(firstPane.waitForExistence(timeout: 5), "First metric pane should appear")
        XCTAssertTrue(secondPane.waitForExistence(timeout: 5), "Second metric pane should appear")

        let firstRange = firstPane.staticTexts["comparison-date-range"].firstMatch
        let secondRange = secondPane.staticTexts["comparison-date-range"].firstMatch
        XCTAssertTrue(firstRange.waitForExistence(timeout: 5), "First metric should show its date range")
        XCTAssertTrue(secondRange.waitForExistence(timeout: 5), "Second metric should show its date range")
        let initialRange = firstRange.label
        XCTAssertFalse(initialRange.isEmpty, "Comparison dates should be readable")
        XCTAssertEqual(initialRange, secondRange.label, "Both metrics should use the same initial dates")

        if VisualAudit.isEnabled {
            for name in ["charts"] {
                VisualAudit.capture("Metric comparison \(name) initial viewport")
                for index in 1...3 {
                    app.scrollViews.firstMatch.swipeUp()
                    VisualAudit.capture("Metric comparison \(name) lower viewport \(index)")
                }
            }
        }

        let comparisonScroll = app.scrollViews.firstMatch
        for _ in 0..<12 where !app.buttons["metric-comparison-period"].isHittable {
            comparisonScroll.swipeDown()
        }
        XCTAssertTrue(app.waitAndTap("metric-comparison-period"), "Period menu should open")
        XCTAssertTrue(app.waitAndTap("metric-comparison-period-M"), "Shared period picker should offer month")
        let rangesUpdated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            firstRange.exists && secondRange.exists
                && firstRange.label != initialRange
                && firstRange.label == secondRange.label
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rangesUpdated], timeout: 5), .completed,
                       "Changing the shared period should update both date ranges together")

        XCTAssertTrue(app.waitAndTap("metric-comparison-done"), "Comparison should expose Done")
        let comparisonDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: firstPane
        )
        XCTAssertEqual(XCTWaiter.wait(for: [comparisonDismissed], timeout: 5), .completed)
        XCTAssertTrue(app.buttons[AXID.wellnessToolbarAdd].waitForExistence(timeout: 5),
                      "Done should return to Wellness")
    }

    func testWellnessRootRendersAndHeroOpensScoreDetail() throws {
        XCTAssertTrue(waitForElement(AXID.wellnessHeroScore, timeout: 15).exists, "Wellness hero should exist")
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessCardHRV, maxSwipes: 4), "Active section should expose the HRV card")
        XCTAssertTrue(elementExists(AXID.wellnessCardHRV, timeout: 5), "HRV card should render in the active section")
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessLinkInjuryHistory, maxSwipes: 6), "Injury history link should be reachable")
        XCTAssertTrue(elementExists(AXID.wellnessLinkInjuryHistory, timeout: 5), "Injury section should render in seeded state")
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessLinkBodyHistory, maxSwipes: 6), "Body history link should be reachable")
        XCTAssertTrue(elementExists(AXID.wellnessLinkBodyHistory, timeout: 5), "Body history link should render in seeded state")
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.wellnessHeroScore, maxSwipes: 6, direction: .down),
            "Wellness hero should remain reachable after scrolling through sections"
        )

        app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch.auditTap()

        let detail = app.descendants(matching: .any)[AXID.wellnessScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Wellness score detail should open from hero")
    }

    func testHRVCardOpensMetricDetailAndAllData() throws {
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.wellnessCardHRV, maxSwipes: 6),
            "HRV card should be reachable in Wellness tab"
        )

        let hrvCard = app.descendants(matching: .any)[AXID.wellnessCardHRV].firstMatch
        XCTAssertTrue(hrvCard.waitForExistence(timeout: 8), "HRV card should exist")
        hrvCard.auditTap()

        let metricDetail = app.descendants(matching: .any)[AXID.metricDetailScreen("hrv")].firstMatch
        XCTAssertTrue(metricDetail.waitForExistence(timeout: 8), "HRV metric detail should open")

        let showAllData = app.descendants(matching: .any)[AXID.metricDetailShowAllData].firstMatch
        XCTAssertTrue(showAllData.waitForExistence(timeout: 5), "Show All Data should exist from HRV detail")
        showAllData.auditTap()

        let allData = app.descendants(matching: .any)[AXID.allDataScreen("hrv")].firstMatch
        XCTAssertTrue(allData.waitForExistence(timeout: 8), "All Data should open from HRV detail")
    }

    func testBodyAddFlowSavesRecord() throws {
        openBodyFormFromToolbar()

        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Body form save button should exist")
        let bodyForm = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        saveButton.auditTap()
        XCTAssertTrue(bodyForm.waitForExistence(timeout: 2), "Body form should remain visible before body input")

        XCTAssertTrue(app.fillTextInput(AXID.bodyFormWeight, with: "91.2"), "Weight field should accept a seeded regression value")
        saveButton.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: bodyForm)
        waitForExpectations(timeout: 10)

        openBodyHistory()
        XCTAssertTrue(app.staticTexts["91.2 kg"].firstMatch.waitForExistence(timeout: 8), "Newly saved weight should appear in body history")
    }

    func testBodyHistoryRowOpensEditFormAndSaves() throws {
        try verifyBodyHistoryEditAndSave(checkLowerFields: VisualAudit.isEnabled)
    }

    func testBodyHistoryEditAndSaveAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        try verifyBodyHistoryEditAndSave(checkLowerFields: true)
    }

    private func verifyBodyHistoryEditAndSave(checkLowerFields: Bool) throws {
        openBodyHistory()

        let manualRow = firstElement(withIdentifierPrefix: "body-history-row-manual-")
        XCTAssertTrue(manualRow.waitForExistence(timeout: 8), "At least one manual body history row should exist")
        manualRow.press(forDuration: 1.2)

        let editAction = app.descendants(matching: .any)[AXID.bodyHistoryEditAction].firstMatch
        XCTAssertTrue(editAction.waitForExistence(timeout: 5), "Body edit action should appear from context menu")
        editAction.auditTap()

        let form = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Edit body form should appear")
        XCTAssertTrue(app.fillTextInput(AXID.bodyFormWeight, with: "88.8"), "Edit form should allow weight changes")
        XCTAssertEqual(app.textFields[AXID.bodyFormWeight].firstMatch.value as? String, "88.8",
                       "Replacement must not append to the seeded weight")
        if checkLowerFields {
            VisualAudit.capture("Body edit weight with keyboard")
            let keyboardDone = app.buttons["body-form-keyboard-done"].firstMatch
            XCTAssertTrue(keyboardDone.waitForExistence(timeout: 3), "Body numeric keyboard must have a dismiss action")
            keyboardDone.auditTap()
            let formScroll = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
            XCTAssertNotNil(formScroll, "Body edit form must provide a visible scroll container")
            formScroll?.swipeUp()
            for identifier in [AXID.bodyFormFat, AXID.bodyFormMuscle] {
                let field = app.textFields[identifier]
                for _ in 0..<12 where !(field.exists && field.isHittable) {
                    if field.exists && field.frame.midY < (formScroll?.frame.midY ?? 0) {
                        formScroll?.swipeDown()
                    } else {
                        formScroll?.swipeUp()
                    }
                }
                XCTAssertTrue(field.exists && field.isHittable,
                              "Every body measurement field must be reachable")
                VisualAudit.capture("Body edit field \(identifier)")
            }
        }

        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Body save button should exist in edit mode")
        XCTAssertTrue(saveButton.isHittable, "Body save button must remain usable after scrolling through measurements")
        VisualAudit.capture("Body edit lower fields with usable Save")
        saveButton.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 10)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.bodyHistoryDetailScreen].firstMatch.waitForExistence(timeout: 8),
            "Body history screen should remain visible after saving edit"
        )
        let editedWeight = app.staticTexts["88.8 kg"].firstMatch
        XCTAssertTrue(editedWeight.waitForExistence(timeout: 8), "Edited weight should appear in body history")
        XCTAssertTrue(editedWeight.isHittable, "History must be usable, without an empty modal covering it")
        XCTAssertEqual(app.sheets.count, 0, "Saving must dismiss every edit sheet")
        VisualAudit.capture("Body history remains usable after saving")
    }

    func testInjuryAddFlowShowsRecoveredFieldsAndCreatesHistoryRow() throws {
        openInjuryFormFromToolbar()

        let recoveredToggle = app.descendants(matching: .any)[AXID.injuryFormRecoveredToggle].firstMatch
        XCTAssertTrue(recoveredToggle.waitForExistence(timeout: 5), "Recovered toggle should exist")
        XCTAssertTrue(
            app.setSwitch(AXID.injuryFormRecoveredToggle, to: true, fallbackLabel: "Recovered"),
            "Recovered toggle should turn on"
        )

        XCTAssertTrue(
            app.scrollToInjuryEndDateIfNeeded(maxSwipes: 4, timeoutPerCheck: 1.5),
            "End date should appear after enabling recovered"
        )

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Injury save button should exist")
        saveButton.auditTap()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 10)

        openInjuryHistory()
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "injury-history-row-"))
        XCTAssertGreaterThanOrEqual(rows.count, 2, "A newly saved injury should add another history row")
    }

    func testInjuryHistoryRowOpensDetailAndEditForm() throws {
        openInjuryHistory()

        let row = app.descendants(matching: .any)[AXID.injuryHistoryRow(0)].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Seeded injury row should exist")
        VisualAudit.capture("Injury history names and metadata")
        row.auditTap()

        let detail = app.descendants(matching: .any)[AXID.injuryDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "Injury detail should open from history row")

        let editButton = app.descendants(matching: .any)[AXID.injuryDetailEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Injury detail edit button should exist")
        editButton.auditTap()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Edit injury form should appear")

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist in edit mode")
        saveButton.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "Saving edit should return to injury detail")
    }

    func testInjuryStatisticsRouteOpensFromHistory() throws {
        openInjuryHistory()

        let statsButton = app.descendants(matching: .any)[AXID.injuryHistoryStats].firstMatch
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5), "Injury statistics button should exist")
        statsButton.auditTap()

        let screen = app.descendants(matching: .any)[AXID.injuryStatisticsScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Injury statistics screen should open from history")
        if VisualAudit.isEnabled {
            VisualAudit.capture("Injury statistics initial viewport")
            for index in 1...4 {
                app.scrollViews.firstMatch.swipeUp()
                VisualAudit.capture("Injury statistics lower viewport \(index)")
            }
        }
    }

    private func openBodyFormFromToolbar() {
        ensureWellnessRoot()
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Wellness add menu should exist")
        addMenu.auditTap()

        let bodyButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyButton.waitForExistence(timeout: 5), "Body Record menu action should exist")
        bodyButton.auditTap()

        let form = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Body form should open from toolbar add menu")
    }

    private func openInjuryFormFromToolbar() {
        ensureWellnessRoot()
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Wellness add menu should exist")
        addMenu.auditTap()

        let injuryButton = app.descendants(matching: .any)[AXID.wellnessMenuInjury].firstMatch
        XCTAssertTrue(injuryButton.waitForExistence(timeout: 5), "Injury menu action should exist")
        injuryButton.auditTap()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Injury form should open from toolbar add menu")
    }

    private func openBodyHistory() {
        ensureWellnessRoot()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessLinkBodyHistory, maxSwipes: 6), "Body history link should be reachable")
        let bodyHistoryLink = app.descendants(matching: .any)[AXID.wellnessLinkBodyHistory].firstMatch
        XCTAssertTrue(bodyHistoryLink.waitForExistence(timeout: 8), "Body history link should exist")
        bodyHistoryLink.auditTap()

        let screen = app.descendants(matching: .any)[AXID.bodyHistoryDetailScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Body history detail should open")
    }

    private func openInjuryHistory() {
        ensureWellnessRoot()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessLinkInjuryHistory, maxSwipes: 6), "Injury history link should be reachable")
        let injuryHistoryLink = app.descendants(matching: .any)[AXID.wellnessLinkInjuryHistory].firstMatch
        XCTAssertTrue(injuryHistoryLink.waitForExistence(timeout: 8), "Injury history link should exist")
        injuryHistoryLink.auditTap()

        let screen = app.descendants(matching: .any)[AXID.injuryHistoryScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Injury history should open")
    }

    private func ensureWellnessRoot() {
        let hero = app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
        if hero.exists || hero.waitForExistence(timeout: 8) {
            return
        }

        navigateToWellness()
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "Wellness hero should exist after returning to root")
    }

    private func firstElement(withIdentifierPrefix prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }
}

/// Opt-in route coverage using synthetic posture measurements, never camera inference.
@MainActor
final class PostureVisualAuditTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "wellness" }
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-visual-posture-fixtures"]
    }

    override func setUpWithError() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        try super.setUpWithError()
    }

    func testPostureHistoryAndDetail() throws {
        openHistory()
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics"))
        let row = rows.firstMatch
        reveal(row)
        XCTAssertTrue(row.exists && row.isHittable, "Seeded posture record should be reachable")
        row.auditTap()
        VisualAudit.capture("Posture detail top")
        captureScrollContent("Posture detail", count: 5)
    }

    func testPostureComparison() throws {
        openHistory()
        let compare = app.buttons["Compare"].firstMatch
        XCTAssertTrue(compare.waitForExistence(timeout: 5))
        compare.auditTap()
        let metrics = app.staticTexts.matching(NSPredicate(format: "label == %@", "8 metrics"))
        XCTAssertEqual(metrics.count, 2, "Both synthetic records should be selectable")
        for index in 0..<2 {
            let metric = metrics.element(boundBy: index)
            reveal(metric)
            metric.auditTap()
        }
        let selected = app.buttons["Compare Selected"].firstMatch
        reveal(selected)
        XCTAssertTrue(selected.exists && selected.isHittable)
        selected.auditTap()
        XCTAssertTrue(app.navigationBars["Comparison"].waitForExistence(timeout: 5),
                      "Compare Selected must reach the comparison destination")
        VisualAudit.capture("Posture comparison top")
        for identifier in ["posture-comparison-photos-scroll", "posture-comparison-metrics-scroll"] {
            let pane = app.scrollViews[identifier].firstMatch
            XCTAssertTrue(pane.waitForExistence(timeout: 5), "Both comparison panes must remain available")
            XCTAssertTrue(pane.isHittable, "Comparison pane must be scrollable: \(identifier)")
            pane.swipeUp(velocity: .slow)
            VisualAudit.capture("Posture comparison lower pane \(identifier)")
        }
    }

    func testPostureSymmetry() throws {
        openHistory()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics")).firstMatch
        reveal(row)
        XCTAssertTrue(row.exists && row.isHittable)
        row.auditTap()
        let symmetry = app.buttons["posture-symmetry-link"].firstMatch
        reveal(symmetry)
        XCTAssertTrue(symmetry.exists && symmetry.isHittable)
        symmetry.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)["posture-symmetry-screen"].firstMatch.waitForExistence(timeout: 10),
            "Symmetry link should navigate to its detail screen"
        )
        VisualAudit.capture("Posture symmetry top")
        captureScrollContent("Posture symmetry", count: 3)
    }

    func testCameraAndRealtimeAvailability() throws {
        for identifier in ["wellness-menu-posture", "wellness-menu-realtime-posture"] {
            XCTAssertTrue(app.waitAndTapToolbarAction(AXID.wellnessToolbarAdd))
            XCTAssertTrue(app.waitAndTap(identifier))
            VisualAudit.capture("Camera availability \(identifier)")
            if identifier == "wellness-menu-realtime-posture" {
                let picker = app.buttons["Select Exercise"].firstMatch
                if picker.waitForExistence(timeout: 3) {
                    picker.auditTap()
                    VisualAudit.capture("Realtime exercise picker")
                    if app.buttons["Cancel"].firstMatch.exists {
                        app.buttons["Cancel"].firstMatch.auditTap()
                    }
                }
            }
            let close = app.buttons["Close"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            close.auditTap()
        }
    }

    private func openHistory() {
        let viewAll = app.buttons["View All"].firstMatch
        reveal(viewAll)
        XCTAssertTrue(viewAll.exists && viewAll.isHittable, "Posture history entry should be reachable")
        viewAll.auditTap()
        XCTAssertTrue(app.staticTexts["Posture History"].firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("Posture history top")
    }

    private func reveal(_ element: XCUIElement) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<14 where !(element.exists && element.isHittable) {
            if element.exists && element.frame.midY < scroll.frame.midY {
                scroll.swipeDown(velocity: .slow)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        VisualAudit.capture("Posture route target viewport")
    }

    private func captureScrollContent(_ label: String, count: Int) {
        for index in 1...count {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            VisualAudit.capture("\(label) lower viewport \(index)")
        }
    }
}
