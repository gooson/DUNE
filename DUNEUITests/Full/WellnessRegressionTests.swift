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

        app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch.tap()

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
        hrvCard.tap()

        let metricDetail = app.descendants(matching: .any)[AXID.metricDetailScreen("hrv")].firstMatch
        XCTAssertTrue(metricDetail.waitForExistence(timeout: 8), "HRV metric detail should open")

        let showAllData = app.descendants(matching: .any)[AXID.metricDetailShowAllData].firstMatch
        XCTAssertTrue(showAllData.waitForExistence(timeout: 5), "Show All Data should exist from HRV detail")
        showAllData.tap()

        let allData = app.descendants(matching: .any)[AXID.allDataScreen("hrv")].firstMatch
        XCTAssertTrue(allData.waitForExistence(timeout: 8), "All Data should open from HRV detail")
    }

    func testBodyAddFlowSavesRecord() throws {
        openBodyFormFromToolbar()

        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Body form save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled before body input")

        XCTAssertTrue(app.fillTextInput(AXID.bodyFormWeight, with: "91.2"), "Weight field should accept a seeded regression value")
        XCTAssertTrue(saveButton.isEnabled, "Save should enable after entering a body value")
        saveButton.tap()

        let bodyForm = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: bodyForm)
        waitForExpectations(timeout: 5)

        openBodyHistory()
        XCTAssertTrue(app.staticTexts["91.2 kg"].firstMatch.waitForExistence(timeout: 8), "Newly saved weight should appear in body history")
    }

    func testBodyHistoryRowOpensEditFormAndSaves() throws {
        openBodyHistory()

        let manualRow = firstElement(withIdentifierPrefix: "body-history-row-manual-")
        XCTAssertTrue(manualRow.waitForExistence(timeout: 8), "At least one manual body history row should exist")
        manualRow.press(forDuration: 1.2)

        let editAction = app.descendants(matching: .any)[AXID.bodyHistoryEditAction].firstMatch
        XCTAssertTrue(editAction.waitForExistence(timeout: 5), "Body edit action should appear from context menu")
        editAction.tap()

        let form = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Edit body form should appear")
        XCTAssertTrue(app.fillTextInput(AXID.bodyFormWeight, with: "88.8"), "Edit form should allow weight changes")

        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Body save button should exist in edit mode")
        saveButton.tap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.bodyHistoryDetailScreen].firstMatch.waitForExistence(timeout: 8),
            "Body history screen should remain visible after saving edit"
        )
        XCTAssertTrue(app.staticTexts["88.8 kg"].firstMatch.waitForExistence(timeout: 8), "Edited weight should appear in body history")
    }

    func testInjuryAddFlowShowsRecoveredFieldsAndCreatesHistoryRow() throws {
        openInjuryFormFromToolbar()

        let recoveredToggle = app.descendants(matching: .any)[AXID.injuryFormRecoveredToggle].firstMatch
        XCTAssertTrue(recoveredToggle.waitForExistence(timeout: 5), "Recovered toggle should exist")
        recoveredToggle.tap()

        let endDate = app.descendants(matching: .any)[AXID.injuryFormEndDate].firstMatch
        XCTAssertTrue(endDate.waitForExistence(timeout: 5), "End date should appear after enabling recovered")

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Injury save button should exist")
        saveButton.tap()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 5)

        openInjuryHistory()
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "injury-history-row-"))
        XCTAssertGreaterThanOrEqual(rows.count, 2, "A newly saved injury should add another history row")
    }

    func testInjuryHistoryRowOpensDetailAndEditForm() throws {
        openInjuryHistory()

        let row = app.descendants(matching: .any)[AXID.injuryHistoryRow(0)].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Seeded injury row should exist")
        row.tap()

        let detail = app.descendants(matching: .any)[AXID.injuryDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "Injury detail should open from history row")

        let editButton = app.descendants(matching: .any)[AXID.injuryDetailEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Injury detail edit button should exist")
        editButton.tap()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Edit injury form should appear")

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist in edit mode")
        saveButton.tap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "Saving edit should return to injury detail")
    }

    func testInjuryStatisticsRouteOpensFromHistory() throws {
        openInjuryHistory()

        let statsButton = app.descendants(matching: .any)[AXID.injuryHistoryStats].firstMatch
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5), "Injury statistics button should exist")
        statsButton.tap()

        let screen = app.descendants(matching: .any)[AXID.injuryStatisticsScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Injury statistics screen should open from history")
    }

    private func openBodyFormFromToolbar() {
        ensureWellnessRoot()
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Wellness add menu should exist")
        addMenu.tap()

        let bodyButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyButton.waitForExistence(timeout: 5), "Body Record menu action should exist")
        bodyButton.tap()

        let form = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Body form should open from toolbar add menu")
    }

    private func openInjuryFormFromToolbar() {
        ensureWellnessRoot()
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Wellness add menu should exist")
        addMenu.tap()

        let injuryButton = app.descendants(matching: .any)[AXID.wellnessMenuInjury].firstMatch
        XCTAssertTrue(injuryButton.waitForExistence(timeout: 5), "Injury menu action should exist")
        injuryButton.tap()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Injury form should open from toolbar add menu")
    }

    private func openBodyHistory() {
        ensureWellnessRoot()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessLinkBodyHistory, maxSwipes: 6), "Body history link should be reachable")
        let bodyHistoryLink = app.descendants(matching: .any)[AXID.wellnessLinkBodyHistory].firstMatch
        XCTAssertTrue(bodyHistoryLink.waitForExistence(timeout: 8), "Body history link should exist")
        bodyHistoryLink.tap()

        let screen = app.descendants(matching: .any)[AXID.bodyHistoryDetailScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Body history detail should open")
    }

    private func openInjuryHistory() {
        ensureWellnessRoot()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.wellnessLinkInjuryHistory, maxSwipes: 6), "Injury history link should be reachable")
        let injuryHistoryLink = app.descendants(matching: .any)[AXID.wellnessLinkInjuryHistory].firstMatch
        XCTAssertTrue(injuryHistoryLink.waitForExistence(timeout: 8), "Injury history link should exist")
        injuryHistoryLink.tap()

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
