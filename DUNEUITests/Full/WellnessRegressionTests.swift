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

    func testDesertHeroKeepsSleepEmptyStateAndScoreNavigation() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-test-theme", "desertWarm",
            "--ui-test-no-sleep-trend"
        ]
        launchApp(with: configuration)
        navigateToWellness()

        let hero = app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
        let sleepEmptyState = app.descendants(matching: .any)["wellness-sleep-empty-state"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Desert Wellness hero should retain the seeded score")
        XCTAssertTrue(sleepEmptyState.waitForExistence(timeout: 10),
                      "Missing sleep trend should show an honest empty state inside the hero")
        XCTAssertTrue(app.descendants(matching: .any)["wellness-sleep-summary-card"].firstMatch.exists,
                      "The sleep empty state should belong to the independent sleep card")
        XCTAssertTrue(hero.frame.minY < sleepEmptyState.frame.minY,
                      "Independent sleep should follow the hero in the Desert layout")

        hero.tap()
        let detail = app.descendants(matching: .any)[AXID.wellnessScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10),
                      "Wellness score detail should remain reachable without a sleep trend")
    }

    func testCompareMetricsSharesPeriodAndDismisses() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--uitest-long-metric-history"]
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(app.waitAndTapToolbarAction("wellness-compare-metrics"),
                      "Wellness should expose metric comparison directly or in toolbar overflow")
        let firstPane = app.descendants(matching: .any)["metric-comparison-first"].firstMatch
        let secondPane = app.descendants(matching: .any)["metric-comparison-second"].firstMatch
        XCTAssertTrue(firstPane.waitForExistence(timeout: 5))
        XCTAssertTrue(secondPane.waitForExistence(timeout: 5))
        let sharedDate = app.staticTexts["comparison-date-range"].firstMatch
        XCTAssertTrue(sharedDate.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "comparison-date-range").count, 1)
        let weekLabel = sharedDate.label
        XCTAssertFalse(weekLabel.isEmpty)
        XCTAssertTrue(app.staticTexts["Same dates; separate scales. Trends do not establish cause."].firstMatch.exists)
        VisualAudit.capture("H04 shared week and initial charts")

        let firstPicker = firstPane.descendants(matching: .any)["metric-comparison-first-picker"].firstMatch
        let secondPicker = secondPane.descendants(matching: .any)["metric-comparison-second-picker"].firstMatch
        XCTAssertTrue(firstPicker.waitForExistence(timeout: 5))
        let comparisonScroll = app.scrollViews["metric-comparison-scroll"].firstMatch
        XCTAssertTrue(comparisonScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(revealComparisonControl("metric-comparison-first-picker", in: comparisonScroll))
        XCTAssertTrue(firstPicker.isEnabled)
        firstPicker.tap()
        let hrv = app.descendants(matching: .any)["metric-comparison-first-option-hrv"].firstMatch
        XCTAssertTrue(hrv.waitForExistence(timeout: 5))
        XCTAssertTrue(hrv.isEnabled && hrv.isHittable)
        hrv.tap()
        XCTAssertTrue(secondPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(revealComparisonControl("metric-comparison-second-picker", in: comparisonScroll))
        XCTAssertTrue(secondPicker.isEnabled)
        secondPicker.tap()
        let weight = app.descendants(matching: .any)["metric-comparison-second-option-weight"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertTrue(weight.isEnabled && weight.isHittable)
        weight.tap()
        XCTAssertTrue(firstPane.staticTexts["HRV"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(secondPane.staticTexts["Weight"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(firstPane.staticTexts["ms"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(secondPane.staticTexts["kg"].firstMatch.waitForExistence(timeout: 10))
        let firstPlot = app.descendants(matching: .any)["metric-comparison-first-plot"].firstMatch
        let secondPlot = app.descendants(matching: .any)["metric-comparison-second-plot"].firstMatch
        XCTAssertTrue(firstPlot.waitForExistence(timeout: 10), "Fixture HRV must render an actual plot")
        XCTAssertTrue(secondPlot.waitForExistence(timeout: 10), "Seeded Weight must render an actual plot")
        captureComparisonPlot(firstPlot, named: "H04 normal HRV plot and ms", in: comparisonScroll)
        captureComparisonPlot(secondPlot, named: "H04 normal Weight plot and kg", in: comparisonScroll)

        let inlinePeriods = app.descendants(matching: .any)["metric-comparison-period-options"].firstMatch
        let month = app.descendants(matching: .any)["metric-comparison-period-M"].firstMatch
        if inlinePeriods.exists {
            XCTAssertTrue(revealComparisonControl("metric-comparison-period-M", in: comparisonScroll))
            XCTAssertTrue(comparisonScroll.frame.intersection(app.windows.firstMatch.frame).contains(month.frame))
            XCTAssertTrue(month.isEnabled && month.isHittable)
            month.tap()
        } else {
            XCTAssertTrue(revealComparisonNormalPeriodMenu(in: comparisonScroll),
                          "The unique normal Period menu must be fully visible and enabled below navigation")
            app.descendants(matching: .any)["metric-comparison-period"].firstMatch.tap()
            XCTAssertTrue(month.waitForExistence(timeout: 5))
            XCTAssertTrue(month.isEnabled && month.isHittable)
            month.tap()
        }
        let monthRange = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", weekLabel), object: sharedDate
        )
        XCTAssertEqual(XCTWaiter.wait(for: [monthRange], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts.matching(identifier: "comparison-date-range").count, 1)
        if inlinePeriods.exists {
            XCTAssertTrue(month.isSelected, "The shared month period must show its selected state")
        }
        XCTAssertTrue(firstPane.staticTexts["ms"].firstMatch.exists)
        XCTAssertTrue(secondPane.staticTexts["kg"].firstMatch.exists)
        VisualAudit.capture("H04 shared month with independent units")
        XCTAssertTrue(revealComparisonControl("metric-comparison-second-picker", in: comparisonScroll))
        VisualAudit.capture("H04 second pane reachable")

        let done = app.descendants(matching: .any)["metric-comparison-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled && done.isHittable && app.windows.firstMatch.frame.contains(done.frame))
        done.tap()
        XCTAssertTrue(firstPane.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AXID.wellnessToolbarAdd].waitForExistence(timeout: 5))
        VisualAudit.capture("H04 Done returns Wellness")
    }

    func testCompareMetricsDarkMaximumAccessibility() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--uitest-long-metric-history",
            "--ui-test-style", "dark", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL", "--ui-disable-animations"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(app.waitAndTapToolbarAction("wellness-compare-metrics"))
        let title = app.descendants(matching: .any)["metric-comparison-title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows.firstMatch.frame.contains(title.frame),
                      "The comparison heading should fit the active window")
        let firstPane = app.descendants(matching: .any)["metric-comparison-first"].firstMatch
        let secondPane = app.descendants(matching: .any)["metric-comparison-second"].firstMatch
        XCTAssertTrue(firstPane.waitForExistence(timeout: 5))
        XCTAssertTrue(secondPane.waitForExistence(timeout: 5))
        let sharedDate = app.staticTexts["comparison-date-range"].firstMatch
        XCTAssertTrue(sharedDate.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "comparison-date-range").count, 1)
        let weekLabel = sharedDate.label
        VisualAudit.capture("H04 MAX title and shared week")

        let comparisonScroll = app.scrollViews["metric-comparison-scroll"].firstMatch
        XCTAssertTrue(comparisonScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(revealComparisonControl("metric-comparison-first-picker", in: comparisonScroll))
        let firstPicker = app.descendants(matching: .any)["metric-comparison-first-picker"].firstMatch
        XCTAssertTrue(firstPicker.isEnabled)
        firstPicker.tap()
        XCTAssertTrue(tapComparisonMenuOption("metric-comparison-first-option-rhr"),
                      "The uniquely identified RHR option must be fully visible and enabled in the native menu")
        let restingHR = firstPane.staticTexts["Resting HR"].firstMatch
        XCTAssertTrue(restingHR.waitForExistence(timeout: 5))
        XCTAssertTrue(firstPane.staticTexts["bpm"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(revealComparisonControl(restingHR, in: comparisonScroll))
        XCTAssertTrue(revealComparisonControl(firstPicker, in: comparisonScroll),
                      "Selected Resting HR picker row must fit at MAX")
        VisualAudit.capture("H04 MAX selected Resting HR full row")
        XCTAssertTrue(revealComparisonControl(firstPicker, in: comparisonScroll))
        firstPicker.tap()
        XCTAssertTrue(tapComparisonMenuOption("metric-comparison-first-option-hrv"),
                      "The uniquely identified HRV option must be fully visible and enabled in the native menu")
        XCTAssertTrue(firstPane.staticTexts["ms"].firstMatch.waitForExistence(timeout: 10))
        let firstPlot = app.descendants(matching: .any)["metric-comparison-first-plot"].firstMatch
        XCTAssertTrue(firstPlot.waitForExistence(timeout: 10))
        XCTAssertTrue(revealComparisonPlotEdge(firstPlot, top: true, in: comparisonScroll),
                      "The first HRV plot's upper edge must reach the visible viewport")
        VisualAudit.capture("H04 MAX first HRV plot")
        XCTAssertTrue(revealComparisonControl("metric-comparison-second-picker", in: comparisonScroll))
        let secondPicker = app.descendants(matching: .any)["metric-comparison-second-picker"].firstMatch
        XCTAssertTrue(secondPicker.isEnabled)
        secondPicker.tap()
        XCTAssertTrue(tapComparisonMenuOption("metric-comparison-second-option-weight"),
                      "The uniquely identified Weight option must be fully visible and enabled in the native menu")
        let weightUnit = secondPane.staticTexts["kg"].firstMatch
        XCTAssertTrue(weightUnit.waitForExistence(timeout: 10))
        let weightPlot = app.descendants(matching: .any)["metric-comparison-second-plot"].firstMatch
        XCTAssertTrue(weightPlot.waitForExistence(timeout: 10))
        XCTAssertTrue(revealComparisonPlotEdge(weightPlot, top: true, in: comparisonScroll),
                      "The second Weight plot's upper edge must reach the visible viewport")
        XCTAssertTrue(revealComparisonControl(weightUnit, in: comparisonScroll),
                      "The second plot's unit must be fully reachable at MAX")
        VisualAudit.capture("H04 MAX second Weight plot")
        XCTAssertTrue(revealComparisonPlotEdge(weightPlot, top: false, in: comparisonScroll),
                      "The lower chart edge and X axis must reach the visible viewport")
        VisualAudit.capture("H04 MAX second Weight plot lower")

        let month = app.descendants(matching: .any)["metric-comparison-period-M"].firstMatch
        XCTAssertTrue(revealComparisonMonthAfterPlots(in: comparisonScroll),
                      "The unique Month action must return fully into the viewport after both MAX plots")
        let monthViewport = comparisonScroll.frame.intersection(app.windows.firstMatch.frame)
        XCTAssertTrue(monthViewport.contains(month.frame), "The entire month action should fit the scroll viewport")
        XCTAssertTrue(month.isEnabled && month.isHittable)
        month.tap()
        let monthRange = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", weekLabel), object: sharedDate
        )
        XCTAssertEqual(XCTWaiter.wait(for: [monthRange], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts.matching(identifier: "comparison-date-range").count, 1)
        XCTAssertTrue(month.isSelected, "The shared month period must show its selected state at MAX")
        XCTAssertTrue(revealComparisonControl(sharedDate, in: comparisonScroll),
                      "The updated shared month range must be fully visible")
        let sharedDateViewport = comparisonScroll.frame.intersection(app.windows.firstMatch.frame)
        XCTAssertTrue(sharedDateViewport.contains(sharedDate.frame),
                      "The entire shared month range should fit the scroll viewport")
        VisualAudit.capture("H04 MAX shared month")
        let done = app.descendants(matching: .any)["metric-comparison-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled && done.isHittable && app.windows.firstMatch.frame.contains(done.frame))
        done.tap()
        XCTAssertTrue(firstPane.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AXID.wellnessToolbarAdd].waitForExistence(timeout: 5))
        VisualAudit.capture("H04 MAX Done returns Wellness")
    }

    private func revealComparisonNormalPeriodMenu(in scroll: XCUIElement) -> Bool {
        let matches = app.descendants(matching: .any).matching(identifier: "metric-comparison-period")
        let period = matches.firstMatch
        guard period.waitForExistence(timeout: 5), matches.count == 1 else { return false }
        for attempt in 0...12 {
            guard matches.count == 1 else { return false }
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            guard !viewport.isNull && !viewport.isEmpty else { return false }
            let frame = period.frame
            guard frame.width > 0 && frame.height > 0 else { return false }
            if viewport.contains(frame) && period.isEnabled && period.isHittable { return true }
            guard attempt < 12 else { break }
            let delta = frame.midY - viewport.midY
            guard abs(delta) >= 1 else { return false }
            let travel = min(max(abs(delta), viewport.height * 0.20), viewport.height * 0.70)
            let direction: CGFloat = delta < 0 ? 1 : -1
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let x = viewport.midX - scroll.frame.minX
            let startY = viewport.midY - direction * travel / 2 - scroll.frame.minY
            let endY = viewport.midY + direction * travel / 2 - scroll.frame.minY
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY))
            )
        }
        return false
    }

    private func revealComparisonMonthAfterPlots(in scroll: XCUIElement) -> Bool {
        let matches = app.descendants(matching: .any).matching(identifier: "metric-comparison-period-M")
        let month = matches.firstMatch
        guard month.waitForExistence(timeout: 5), matches.count == 1 else { return false }
        for attempt in 0...12 {
            guard matches.count == 1 else { return false }
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            guard !viewport.isNull && !viewport.isEmpty else { return false }
            let frame = month.frame
            guard frame.width > 0 && frame.height > 0 else { return false }
            if viewport.contains(frame) && month.isEnabled && month.isHittable { return true }
            guard attempt < 12 else { break }
            let delta = frame.midY - viewport.midY
            guard abs(delta) >= 1 else { return false }
            let travel = min(max(abs(delta), viewport.height * 0.20), viewport.height * 0.70)
            let direction: CGFloat = delta < 0 ? 1 : -1
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let x = viewport.midX - scroll.frame.minX
            let startY = viewport.midY - direction * travel / 2 - scroll.frame.minY
            let endY = viewport.midY + direction * travel / 2 - scroll.frame.minY
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY))
            )
        }
        return false
    }

    private func tapComparisonMenuOption(_ identifier: String) -> Bool {
        // The accessibility-size Menu opens a separate native, virtualized CollectionView.
        // Its content frame is taller than the visible popover; use the popover clip frame.
        let collections = app.collectionViews
        guard collections.count == 1 else { return false }
        let popup = collections.firstMatch
        let content = popup.frame
        let clips = app.otherElements.containing(.collectionView, identifier: nil)
            .allElementsBoundByAccessibilityElement.map(\.frame).filter { frame in
            abs(frame.minX - content.minX) <= 1 && abs(frame.minY - content.minY) <= 1
                && abs(frame.width - content.width) <= 1
                && frame.height >= 100 && frame.height < content.height - 1
        }
        guard let clip = clips.min(by: { $0.height < $1.height }) else { return false }
        let viewport = clip.intersection(app.windows.firstMatch.frame)
        guard !viewport.isNull && !viewport.isEmpty else { return false }
        let matches = popup.descendants(matching: .any).matching(identifier: identifier)
        for attempt in 0...8 {
            let count = matches.count
            guard count <= 1 else { return false }
            if count == 1 {
                let option = matches.firstMatch
                if option.isEnabled && option.isHittable && viewport.contains(option.frame) {
                    option.tap()
                    return true
                }
            }
            guard attempt < 8 else { break }
            let optionFrame = count == 1 ? matches.firstMatch.frame : CGRect.null
            let lower = !optionFrame.isNull
                ? optionFrame.maxY > viewport.maxY
                : true
            let origin = popup.coordinate(withNormalizedOffset: .zero)
            let x = viewport.midX - content.minX
            let startY = viewport.minY + viewport.height * (lower ? 0.6 : 0.4) - content.minY
            let endY = viewport.minY + viewport.height * (lower ? 0.4 : 0.6) - content.minY
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY))
            )
        }
        return false
    }

    private func revealComparisonControl(
        _ identifier: String,
        in scroll: XCUIElement
    ) -> Bool {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        return revealComparisonControl(element, in: scroll)
    }

    private func revealComparisonControl(_ element: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        for attempt in 0...12 {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            let frame = element.frame
            if element.isHittable && viewport.contains(frame) { return true }
            guard attempt < 12 else { break }
            if frame.maxY > viewport.maxY {
                dragComparisonScroll(scroll, towardLowerContent: true)
            } else if frame.minY < viewport.minY {
                dragComparisonScroll(scroll, towardLowerContent: false)
            } else {
                return false
            }
        }
        return false
    }

    private func revealComparisonPlotEdge(
        _ plot: XCUIElement,
        top: Bool,
        in scroll: XCUIElement
    ) -> Bool {
        guard plot.waitForExistence(timeout: 5) else { return false }
        for attempt in 0...8 {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            let frame = plot.frame
            let edge = CGPoint(x: frame.midX, y: top ? frame.minY + 1 : frame.maxY - 1)
            if viewport.contains(edge) { return true }
            guard attempt < 8 else { break }
            if edge.y > viewport.maxY {
                dragComparisonScroll(scroll, towardLowerContent: true)
            } else if edge.y < viewport.minY {
                dragComparisonScroll(scroll, towardLowerContent: false)
            } else {
                return false
            }
        }
        return false
    }

    private func captureComparisonPlot(
        _ plot: XCUIElement,
        named name: String,
        in scroll: XCUIElement
    ) {
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
        if plot.frame.height <= viewport.height {
            XCTAssertTrue(revealComparisonControl(plot, in: scroll),
                          "The complete \(name) must fit the visible viewport")
            VisualAudit.capture(name)
        } else {
            XCTAssertTrue(revealComparisonPlotEdge(plot, top: true, in: scroll),
                          "The \(name) upper edge must be reachable")
            VisualAudit.capture("\(name) upper edge")
            XCTAssertTrue(revealComparisonPlotEdge(plot, top: false, in: scroll),
                          "The \(name) lower edge must be reachable")
            VisualAudit.capture("\(name) lower edge")
        }
    }

    private func dragComparisonScroll(_ scroll: XCUIElement, towardLowerContent: Bool) {
        let startY: CGFloat = towardLowerContent ? 0.60 : 0.40
        let endY: CGFloat = towardLowerContent ? 0.40 : 0.60
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end)
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
        VisualAudit.capture("H05 add empty form after Save attempt")

        XCTAssertTrue(app.fillTextInput(AXID.bodyFormWeight, with: "91.2"), "Weight field should accept a seeded regression value")
        VisualAudit.capture("H05 add weight entered")
        app.buttons["body-form-keyboard-done"].firstMatch.auditTap()
        saveButton.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: bodyForm)
        waitForExpectations(timeout: 10)

        openBodyHistory()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Weight: 91.2 kg"))
            .firstMatch.waitForExistence(timeout: 8), "Newly saved weight should appear in body history")
        VisualAudit.capture("H05 add saved history")
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
        VisualAudit.capture("H06 body history rows")
        manualRow.press(forDuration: 1.2)

        let editAction = app.descendants(matching: .any)[AXID.bodyHistoryEditAction].firstMatch
        XCTAssertTrue(editAction.waitForExistence(timeout: 5), "Body edit action should appear from context menu")
        editAction.auditTap()

        let form = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8), "Edit body form should appear")
        if checkLowerFields { VisualAudit.capture("H05 edit form initial") }
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
        let editedWeight = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Weight: 88.8 kg"))
            .firstMatch
        XCTAssertTrue(editedWeight.waitForExistence(timeout: 8), "Edited weight should appear in body history")
        XCTAssertTrue(editedWeight.isHittable, "History must be usable, without an empty modal covering it")
        XCTAssertEqual(app.sheets.count, 0, "Saving must dismiss every edit sheet")
        VisualAudit.capture("Body history remains usable after saving")
    }

    func testInjuryAddFlowShowsRecoveredFieldsAndCreatesHistoryRow() throws {
        openInjuryFormFromToolbar()
        VisualAudit.capture("H08 add initial form")

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
        let endDateRow = app.cells.containing(.staticText, identifier: AXID.injuryFormEndDate).firstMatch
        XCTAssertTrue(revealInjuryFormElement(endDateRow), "The complete End Date row must be visible")
        VisualAudit.capture("H08 add recovered end date")

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Injury save button should exist")
        let cancelButton = app.descendants(matching: .any)[AXID.injuryFormCancel].firstMatch
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(saveButton.isEnabled && saveButton.isHittable && windowFrame.contains(saveButton.frame))
        XCTAssertTrue(cancelButton.exists && cancelButton.isHittable && windowFrame.contains(cancelButton.frame))
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
        VisualAudit.capture("H08 edit initial form")

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist in edit mode")
        saveButton.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: form)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "Saving edit should return to injury detail")
    }

    func testInjuryFormAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        openInjuryFormFromToolbar()

        let form = app.descendants(matching: .any)[AXID.injuryFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8))
        let cancel = app.descendants(matching: .any)[AXID.injuryFormCancel].firstMatch
        let save = app.descendants(matching: .any)[AXID.injuryFormSave].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5) && cancel.isEnabled && cancel.isHittable)
        XCTAssertTrue(save.waitForExistence(timeout: 5) && save.isEnabled && save.isHittable)
        VisualAudit.capture("H08 MAX add title and actions")

        let location = app.descendants(matching: .any)[AXID.injuryFormBodyPart].firstMatch
        XCTAssertTrue(revealInjuryFormControl(AXID.injuryFormBodyPart), "Location must fit and be reachable")
        XCTAssertTrue(location.isEnabled)
        VisualAudit.capture("H08 MAX body part")
        XCTAssertTrue(revealInjuryFormControl(AXID.injuryFormSide), "Default Knee Side must fit")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.injuryFormSide].firstMatch.isEnabled)
        VisualAudit.capture("H08 MAX side")
        for severity in ["minor", "moderate", "severe"] {
            let identifier = "injury-form-severity-\(severity)"
            XCTAssertTrue(revealInjuryFormControl(identifier), "Each severity must fit and be reachable")
            XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.isEnabled)
            VisualAudit.capture("H08 MAX severity \(severity)")
        }
        XCTAssertTrue(revealInjuryFormControl(AXID.injuryFormStartDate), "Start Date must fit")
        VisualAudit.capture("H08 MAX start date")
        XCTAssertTrue(revealInjuryFormControl(AXID.injuryFormRecoveredToggle), "Recovered must fit")
        XCTAssertTrue(app.setSwitch(AXID.injuryFormRecoveredToggle, to: true, fallbackLabel: "Recovered"))
        XCTAssertTrue(app.scrollToInjuryEndDateIfNeeded(maxSwipes: 8, timeoutPerCheck: 1))
        let endDateRow = app.cells.containing(.staticText, identifier: AXID.injuryFormEndDate).firstMatch
        XCTAssertTrue(revealInjuryFormElement(endDateRow), "The complete MAX End Date row must be visible")
        VisualAudit.capture("H08 MAX recovered end date")

        XCTAssertTrue(revealInjuryFormControl(AXID.injuryFormMemo), "Memo must fit")
        let memo = app.descendants(matching: .any)[AXID.injuryFormMemo].firstMatch
        XCTAssertTrue(memo.isEnabled && memo.isHittable)
        memo.auditTap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Software keyboard must appear")
        VisualAudit.capture("H08 MAX memo software keyboard")
        let keyboard = app.keyboards.firstMatch
        let formScroll = app.collectionViews.firstMatch
        XCTAssertTrue(formScroll.exists && formScroll.isHittable)
        for _ in 0..<2 {
            if !keyboard.exists { break }
            let window = app.windows.firstMatch
            let viewport = formScroll.frame.intersection(window.frame)
            let keyboardFrame = keyboard.frame.intersection(window.frame)
            XCTAssertGreaterThan(keyboardFrame.minY, viewport.minY, "A visible Form region must remain above the keyboard")
            let startY = (viewport.minY + keyboardFrame.minY) / 2
            XCTAssertGreaterThan(keyboardFrame.midY, startY, "Keyboard dismissal must drag downward inside the window")
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(
                dx: viewport.midX - window.frame.minX,
                dy: startY - window.frame.minY
            ))
            let end = origin.withOffset(CGVector(
                dx: viewport.midX - window.frame.minX,
                dy: keyboardFrame.midY - window.frame.minY
            ))
            start.press(forDuration: 0.05, thenDragTo: end)
            if keyboard.waitForNonExistence(timeout: 2) { break }
        }
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertTrue(save.isEnabled && save.isHittable && app.windows.firstMatch.frame.contains(save.frame))
        XCTAssertTrue(cancel.isEnabled && cancel.isHittable && app.windows.firstMatch.frame.contains(cancel.frame))
        VisualAudit.capture("H08 MAX Save and Cancel after keyboard dismissal")
        save.auditTap()
        XCTAssertTrue(form.waitForNonExistence(timeout: 10), "Save must dismiss the MAX form")
        openInjuryHistory()
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "injury-history-row-"))
        XCTAssertGreaterThanOrEqual(rows.count, 2, "MAX Save must create a history row")
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

    private func revealInjuryFormControl(_ identifier: String, maxMoves: Int = 12) -> Bool {
        let target = app.descendants(matching: .any)[identifier].firstMatch
        return revealInjuryFormElement(target, maxMoves: maxMoves)
    }

    private func revealInjuryFormElement(_ target: XCUIElement, maxMoves: Int = 12) -> Bool {
        let containers = app.collectionViews.allElementsBoundByIndex
            + app.tables.allElementsBoundByIndex
            + app.scrollViews.allElementsBoundByIndex
        guard let scroll = containers.first(where: { $0.exists && $0.isHittable }) else { return false }
        func visibleViewport() -> CGRect {
            let frame = scroll.frame.intersection(app.windows.firstMatch.frame)
            guard frame.width > 0 && frame.height > 0 else { return .null }
            var top = frame.minY
            var bottom = frame.maxY
            let navigationBar = app.navigationBars.firstMatch
            if navigationBar.exists && navigationBar.isHittable && navigationBar.frame.intersects(frame)
                && navigationBar.frame.minY < frame.midY {
                top = max(top, navigationBar.frame.maxY)
            }
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists && keyboard.isHittable && keyboard.frame.intersects(frame)
                && keyboard.frame.minY > frame.midY {
                bottom = min(bottom, keyboard.frame.minY)
            }
            return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
        }
        for _ in 0..<maxMoves {
            let viewport = visibleViewport()
            guard viewport.width > 0 && viewport.height > 0 else { return false }
            if target.exists && target.isHittable && viewport.contains(target.frame) { return true }
            let delta = target.exists ? target.frame.midY - viewport.midY : viewport.height
            if target.exists && abs(delta) < 1 { return false }
            let distance = min(max(abs(delta), viewport.height * 0.2), viewport.height * 0.65)
            let fraction = distance / scroll.frame.height
            let startY: CGFloat = delta < 0 ? 0.3 : 0.7
            let endY = startY + (delta < 0 ? fraction : -fraction)
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                ))
        }
        let viewport = visibleViewport()
        return target.exists && target.isHittable && viewport.contains(target.frame)
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

    func testWellnessRecentPostureRecordOpensDetail() throws {
        navigateToWellness()
        let record = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "wellness-posture-record-"
        )).firstMatch
        reveal(record)
        XCTAssertTrue(record.exists && record.isHittable, "Recent posture record should be reachable")
        record.auditTap()
        XCTAssertTrue(app.navigationBars["Assessment Detail"].firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("Wellness recent posture record detail")
    }

    func testPostureDetailScoreAcrossFoldStatesAtMaximumTextSize() throws {
        guard ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in fold and native posture score audit only")
        }
        executionTimeAllowance = 600
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        openHistory(maxRevealAttempts: 36)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics")).firstMatch
        reveal(row)
        XCTAssertTrue(row.exists && row.isHittable, "Synthetic posture record should be reachable")
        row.auditTap()
        for state in ["closed", "partiallyOpen", "openFlat"] {
            VisualAudit.capture("FOLD:\(state)")
            let scoreLabel = "Posture score 86 out of 100"
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(scoreLabel, maxSwipes: 16, direction: .down),
                          "Posture score should remain reachable after \(state)")
            let score = app.descendants(matching: .any)[scoreLabel].firstMatch
            XCTAssertEqual(score.label, scoreLabel, "Folding should preserve the synthetic score")
            XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(score.frame),
                          "The complete score card should fit in the \(state) window")
            // The combined label cannot prove the ring's painted text fits.
            VisualAudit.capture("Posture \(state) complete score card at maximum AX")
            reveal(app.staticTexts["Assessment Details"].firstMatch)
            captureScrollContent("Posture \(state) assessment at maximum AX", count: 5)
        }
    }

    func testPostureDetailAtMaximumAccessibilitySize() throws {
        executionTimeAllowance = 600
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        openHistory(maxRevealAttempts: 36)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics")).firstMatch
        reveal(row)
        XCTAssertTrue(row.exists && row.isHittable, "Synthetic posture record should be reachable")
        row.auditTap()

        // The host prepares and verifies the requested layout before this test.
        let scoreLabel = "Posture score 86 out of 100"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(scoreLabel, maxSwipes: 16, direction: .down),
                      "Posture score should remain reachable at maximum text size")
        let score = app.descendants(matching: .any)[scoreLabel].firstMatch
        XCTAssertEqual(score.label, scoreLabel, "The stored synthetic score should be preserved")
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(score.frame),
                      "The complete score card should fit in the prepared layout")
        VisualAudit.capture("Posture static layout complete score card at maximum AX")

        let assessment = app.staticTexts["Assessment Details"].firstMatch
        reveal(assessment)
        XCTAssertTrue(assessment.exists && assessment.isHittable,
                      "Stored assessment metrics should be reachable at maximum text size")
        captureScrollContent("Posture static layout assessment at maximum AX", count: 5)
    }

    func testPostureCardAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        let capture = app.buttons["wellness-button-posture-capture"].firstMatch
        reveal(capture)
        XCTAssertTrue(capture.exists && capture.isHittable)
        VisualAudit.capture("Maximum AX posture card actions")
        let record = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "wellness-posture-record-"
        )).firstMatch
        reveal(record)
        XCTAssertTrue(record.exists && record.isHittable)
        VisualAudit.capture("Maximum AX posture card score and complete metrics label")
        openHistory()
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

    func testPostureSymmetryValuesAcrossFoldStatesAtMaximumTextSize() throws {
        guard ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in fold and native symmetry value audit only")
        }
        executionTimeAllowance = 600
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        openHistory()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics")).firstMatch
        reveal(row)
        XCTAssertTrue(row.exists && row.isHittable)
        row.auditTap()
        let symmetry = app.buttons["posture-symmetry-link"].firstMatch
        reveal(symmetry)
        XCTAssertTrue(symmetry.exists && symmetry.isHittable)
        symmetry.auditTap()

        let values = [
            ("shoulderAsymmetry", "left", "50.0 cm"), ("shoulderAsymmetry", "right", "48.0 cm"),
            ("hipAsymmetry", "left", "0.0 cm"), ("hipAsymmetry", "right", "-1.0 cm"),
            ("kneeAlignment", "left", "8.1°"), ("kneeAlignment", "right", "2.7°")
        ]
        for state in ["closed", "partiallyOpen", "openFlat"] {
            VisualAudit.capture("FOLD:\(state)")
            let scroll = app.scrollViews["posture-symmetry-screen"].firstMatch
            XCTAssertTrue(scroll.waitForExistence(timeout: 8), "Symmetry should remain open after folding")
            for (metric, side, expected) in values {
                let value = app.staticTexts["posture-symmetry-value-\(metric)-\(side)"].firstMatch
                XCTAssertTrue(value.waitForExistence(timeout: 5), "Every synthetic symmetry value should exist")
                for _ in 0..<16 {
                    let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                    if viewport.contains(value.frame) && value.isHittable { break }
                    if value.frame.midY < viewport.midY { scroll.swipeDown(velocity: .slow) }
                    else { scroll.swipeUp(velocity: .slow) }
                }
                XCTAssertEqual(value.label, expected, "Folding must preserve the value and unit")
                XCTAssertTrue(value.isHittable && scroll.frame.intersection(app.windows.firstMatch.frame)
                    .insetBy(dx: 8, dy: 8).contains(value.frame), "The whole symmetry value should be visible")
                let sideLabel = app.staticTexts["posture-symmetry-side-\(metric)-\(side)"].firstMatch
                XCTAssertTrue(sideLabel.exists && sideLabel.frame.height > 0)
                XCTAssertLessThanOrEqual(value.frame.height, sideLabel.frame.height * 1.75,
                                         "A numeric value and unit must remain one line, not wrap character by character")
                VisualAudit.capture("Posture \(state) symmetry \(metric) \(side) complete value")
            }
        }
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

    func testVisualAuditPostureResultOnSimulator() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-design-map-posture-result")
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(app.waitAndTapToolbarAction(AXID.wellnessToolbarAdd))
        XCTAssertTrue(app.waitAndTap("wellness-menu-posture"))
        XCTAssertTrue(app.descendants(matching: .any)["posture-result-screen"].firstMatch
            .waitForExistence(timeout: 10), "Seeded posture result should open")
        VisualAudit.capture("Posture result from visual audit record")
    }

    private func openHistory(maxRevealAttempts: Int = 18) {
        let viewAll = app.buttons["wellness-link-posturehistory"].firstMatch
        reveal(viewAll, maxAttempts: maxRevealAttempts)
        XCTAssertTrue(viewAll.exists && viewAll.isHittable, "Posture history entry should be reachable")
        viewAll.auditTap()
        XCTAssertTrue(app.staticTexts["Posture History"].firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("Posture history top")
    }

    private func reveal(_ element: XCUIElement, maxAttempts: Int = 18) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<maxAttempts {
            // Duo may report offscreen descendants as hittable. The target's
            // tap point must also lie inside the visible scroll viewport.
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
                .insetBy(dx: 12, dy: 90)
            if element.exists && element.isHittable
                && viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                break
            }
            if element.exists && scroll.frame.height > 0 {
                let delta = element.frame.midY - viewport.midY
                let travel = min(max(abs(delta), 30), scroll.frame.height * 0.45)
                    / scroll.frame.height
                let startY: CGFloat = delta < 0 ? 0.3 : 0.7
                let endY = startY + (delta < 0 ? travel : -travel)
                // Full swipes oscillate past a short header button at maximum
                // text size. Move only toward its measured visible position.
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                    ))
            } else if element.exists && element.frame.midY < scroll.frame.midY {
                scroll.swipeDown(velocity: .slow)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            .insetBy(dx: 12, dy: 90)
        XCTAssertTrue(element.exists && element.isHittable
                      && viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)),
                      "Posture target must have a visible tap point")
        VisualAudit.capture("Posture route target viewport")
    }

    private func captureScrollContent(_ label: String, count: Int) {
        for index in 1...count {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            VisualAudit.capture("\(label) lower viewport \(index)")
        }
    }
}
