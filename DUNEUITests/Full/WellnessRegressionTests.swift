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
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-injury-history-fixture"]
        launchApp(with: configuration)
        navigateToWellness()
        openInjuryHistory()

        let row = app.descendants(matching: .any)[AXID.injuryHistoryRow(0)].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Seeded injury row should exist")
        XCTAssertTrue(revealInjuryHistoryRow(0), "Active Knee row must fit")
        XCTAssertTrue(app.staticTexts["Active"].firstMatch.exists, "Active group should be present")
        VisualAudit.capture("Injury history names and metadata")
        XCTAssertTrue(revealInjuryHistoryRow(1), "Recovered Shoulder row must fit")
        XCTAssertTrue(app.staticTexts["Recovered"].firstMatch.exists, "Recovered group should be present")
        VisualAudit.capture("H09 recovered Shoulder history row")
        XCTAssertTrue(revealInjuryHistoryRow(0, towardEarlierContent: true), "Original active row must remain reachable")
        row.auditTap()

        let detail = app.descendants(matching: .any)[AXID.injuryDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "Injury detail should open from history row")
        let detailScroll = app.scrollViews["injury-detail-scroll"].firstMatch
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
        for identifier in ["injury-detail-body-part", "injury-detail-side",
                           "injury-detail-severity", "injury-detail-status",
                           "injury-detail-duration", "injury-detail-description"] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: detailScroll), "Missing or clipped \(identifier)")
        }
        XCTAssertEqual(app.staticTexts["injury-detail-body-part"].firstMatch.label, "Knee")
        XCTAssertEqual(app.staticTexts["injury-detail-status"].firstMatch.label, "Active")
        VisualAudit.capture("H10 active Knee detail summary")
        for identifier in ["injury-detail-start-value", "injury-detail-end-value",
                           "injury-detail-recorded-value"] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: detailScroll), "Missing or clipped \(identifier)")
        }
        VisualAudit.capture("H10 active Knee detail timeline")
        XCTAssertTrue(app.revealFullyVisible("injury-detail-memo-value", in: detailScroll))
        XCTAssertEqual(app.staticTexts["injury-detail-memo-value"].firstMatch.label, "Mild pain during squats")
        VisualAudit.capture("H10 active Knee detail memo")

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

        let markRecovered = app.buttons[AXID.injuryDetailMarkRecovered].firstMatch
        XCTAssertTrue(markRecovered.waitForExistence(timeout: 5), "Active injury should offer Mark Recovered")
        XCTAssertTrue(markRecovered.isHittable, "Mark Recovered must be reachable")
        markRecovered.auditTap()

        let recoveredStatus = app.staticTexts["injury-detail-status"].firstMatch
        let statusChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Recovered"), object: recoveredStatus
        )
        XCTAssertEqual(XCTWaiter.wait(for: [statusChanged], timeout: 5), .completed,
                       "Recovery must update the open detail")
        XCTAssertTrue(detail.exists, "Recovery must keep the detail route open")
        XCTAssertTrue(app.revealFullyVisible("injury-detail-status", in: detailScroll),
                      "Recovered status must be fully visible")
        XCTAssertEqual(recoveredStatus.label, "Recovered")
        let recoveredActionGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: markRecovered
        )
        XCTAssertEqual(XCTWaiter.wait(for: [recoveredActionGone], timeout: 5), .completed,
                       "Recovered injury must not offer Mark Recovered")
        VisualAudit.capture("H10 newly recovered Knee detail")

        returnToInjuryHistory(from: AXID.injuryDetailScreen, navigationTitle: "Injury Detail")
        XCTAssertTrue(revealInjuryHistoryRow(0), "Newly recovered Knee row must remain reachable")
        let recoveredRow = app.buttons[AXID.injuryHistoryRow(0)].firstMatch
        XCTAssertTrue(recoveredRow.exists && recoveredRow.label.contains("Knee"),
                      "Knee must remain in history after recovery")
        XCTAssertFalse(recoveredRow.label.contains("Active"), "Knee must no longer be active")
        XCTAssertTrue(app.staticTexts["Recovered"].firstMatch.exists,
                      "Recovered section must contain the updated record")
        XCTAssertFalse(app.staticTexts["Active"].firstMatch.exists,
                       "No active section should remain after recovering the only active record")
        VisualAudit.capture("H10 newly recovered Knee history")
    }

    func testInjuryDetailAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-injury-history-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        openInjuryHistory()
        XCTAssertTrue(revealInjuryHistoryRow(1), "MAX recovered row must fit before opening detail")
        app.descendants(matching: .any)[AXID.injuryHistoryRow(1)].firstMatch.auditTap()
        let detail = app.descendants(matching: .any)[AXID.injuryDetailScreen].firstMatch
        let detailScroll = app.scrollViews["injury-detail-scroll"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
        for identifier in ["injury-detail-body-part", "injury-detail-side",
                           "injury-detail-severity", "injury-detail-status",
                           "injury-detail-duration", "injury-detail-description"] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: detailScroll), "MAX missing or clipped \(identifier)")
            if ["injury-detail-body-part", "injury-detail-status", "injury-detail-duration"].contains(identifier) {
                VisualAudit.capture("H10 MAX recovered Shoulder \(identifier)")
            }
        }
        XCTAssertEqual(app.staticTexts["injury-detail-body-part"].firstMatch.label, "Shoulder")
        XCTAssertEqual(app.staticTexts["injury-detail-status"].firstMatch.label, "Recovered")
        XCTAssertFalse(app.buttons[AXID.injuryDetailMarkRecovered].firstMatch.exists)
        XCTAssertTrue(app.buttons[AXID.injuryDetailEdit].firstMatch.exists)
        VisualAudit.capture("H10 MAX recovered Shoulder detail summary")
        for identifier in ["injury-detail-start-value", "injury-detail-end-value",
                           "injury-detail-recorded-value"] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: detailScroll), "MAX missing or clipped \(identifier)")
        }
        VisualAudit.capture("H10 MAX recovered Shoulder detail timeline")
        XCTAssertTrue(app.revealFullyVisible("injury-detail-memo-value", in: detailScroll))
        VisualAudit.capture("H10 MAX recovered Shoulder detail memo")
        returnToInjuryHistory(from: AXID.injuryDetailScreen, navigationTitle: "Injury Detail")
    }

    func testInjuryHistoryAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-injury-history-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        openInjuryHistory()

        let firstRow = app.descendants(matching: .any)[AXID.injuryHistoryRow(0)].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8), "Seeded active row must exist before MAX reveal")
        XCTAssertTrue(revealInjuryHistoryRow(0), "MAX Active Knee row must fit in the List viewport")
        XCTAssertTrue(app.staticTexts["Active"].firstMatch.exists)
        VisualAudit.capture("H09 MAX active Knee whole row")
        XCTAssertTrue(revealInjuryHistoryRow(1), "MAX Recovered Shoulder row must fit in the List viewport")
        XCTAssertTrue(app.staticTexts["Recovered"].firstMatch.exists)
        VisualAudit.capture("H09 MAX recovered Shoulder whole row")
    }

    func testInjuryStatisticsRouteOpensFromHistory() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-injury-history-fixture"]
        launchApp(with: configuration)
        navigateToWellness()
        openInjuryHistory()

        let statsButton = app.descendants(matching: .any)[AXID.injuryHistoryStats].firstMatch
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5), "Injury statistics button should exist")
        statsButton.auditTap()

        let screen = app.descendants(matching: .any)[AXID.injuryStatisticsScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Injury statistics should open from history")
        let statsScroll = app.scrollViews["injury-statistics-scroll"].firstMatch
        XCTAssertTrue(statsScroll.waitForExistence(timeout: 5))
        let values = [
            ("injury-statistics-overview-total-value", "2"),
            ("injury-statistics-overview-active-value", "1"),
            ("injury-statistics-overview-average-value", "10d"),
            ("injury-statistics-overview-longest-value", "10d")
        ]
        for (identifier, expected) in values {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: statsScroll), "Missing or clipped \(identifier)")
            XCTAssertEqual(app.staticTexts[identifier].firstMatch.label, expected)
        }
        VisualAudit.capture("H11 injury statistics overview values")
        XCTAssertTrue(app.revealFullyVisible("injury-statistics-frequency-chart", in: statsScroll),
                      "Seeded body-part chart must fit")
        XCTAssertTrue(app.staticTexts["Knee: 1"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Shoulder: 1"].firstMatch.exists)
        VisualAudit.capture("H11 injury statistics frequency graph")
        returnToInjuryHistory(from: AXID.injuryStatisticsScreen, navigationTitle: "Injury Statistics")
    }

    func testInjuryStatisticsAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-injury-history-fixture",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        openInjuryHistory()
        let statsButton = app.descendants(matching: .any)[AXID.injuryHistoryStats].firstMatch
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5))
        statsButton.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.injuryStatisticsScreen].firstMatch.waitForExistence(timeout: 8))
        let statsScroll = app.scrollViews["injury-statistics-scroll"].firstMatch
        let values = [
            ("injury-statistics-overview-total-value", "2"),
            ("injury-statistics-overview-active-value", "1"),
            ("injury-statistics-overview-average-value", "10d"),
            ("injury-statistics-overview-longest-value", "10d")
        ]
        for (identifier, expected) in values {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: statsScroll), "MAX missing or clipped \(identifier)")
            XCTAssertEqual(app.staticTexts[identifier].firstMatch.label, expected)
            if identifier == "injury-statistics-overview-active-value" {
                VisualAudit.capture("H11 MAX injury statistics total and active")
            }
        }
        VisualAudit.capture("H11 MAX injury statistics overview")
        XCTAssertTrue(app.revealFullyVisible("injury-statistics-frequency-chart", in: statsScroll),
                      "MAX frequency chart must fit")
        XCTAssertTrue(app.staticTexts["Knee: 1"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Shoulder: 1"].firstMatch.exists)
        VisualAudit.capture("H11 MAX injury statistics frequency graph")
        returnToInjuryHistory(from: AXID.injuryStatisticsScreen, navigationTitle: "Injury Statistics")
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

    private func revealInjuryHistoryRow(
        _ index: Int, towardEarlierContent: Bool = false, maxMoves: Int = 12
    ) -> Bool {
        let row = app.descendants(matching: .any)[AXID.injuryHistoryRow(index)].firstMatch
        guard let list = app.collectionViews.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable })
            ?? app.tables.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) else {
            return false
        }
        func visibleList() -> CGRect {
            let frame = list.frame.intersection(app.windows.firstMatch.frame)
            guard frame.width > 0 && frame.height > 0 else { return .null }
            let navigationBar = app.navigationBars.firstMatch
            let top = navigationBar.exists && navigationBar.isHittable && navigationBar.frame.intersects(frame)
                ? max(frame.minY, navigationBar.frame.maxY) : frame.minY
            return CGRect(x: frame.minX, y: top, width: frame.width,
                          height: max(0, frame.maxY - top))
        }
        for _ in 0..<maxMoves {
            let viewport = visibleList()
            guard viewport.width > 0 && viewport.height > 0 else { return false }
            if row.exists && row.isHittable && viewport.contains(row.frame) { return true }
            let delta = row.exists ? row.frame.midY - viewport.midY
                : (towardEarlierContent ? -viewport.height : viewport.height)
            if row.exists && abs(delta) < 1 { return false }
            let distance = min(max(abs(delta), viewport.height * 0.2), viewport.height * 0.65)
            let fraction = distance / list.frame.height
            let startY: CGFloat = delta < 0 ? 0.3 : 0.7
            let endY = startY + (delta < 0 ? fraction : -fraction)
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.05, thenDragTo: list.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                ))
        }
        let viewport = visibleList()
        return row.exists && row.isHittable && viewport.contains(row.frame)
    }

    private func returnToInjuryHistory(from destinationID: String, navigationTitle: String) {
        let destination = app.descendants(matching: .any)[destinationID].firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 5), "Destination must be open before Back")

        let namedBack = app.navigationBars[navigationTitle].buttons["Injury History"].firstMatch
        if namedBack.exists && namedBack.isHittable {
            namedBack.auditTap()
        } else {
            // Closed Duo places Back in the action rail rather than the navigation bar.
            let railBackButtons = app.buttons.matching(identifier: "BackButton")
            let railBack = railBackButtons.firstMatch
            guard railBack.waitForExistence(timeout: 5),
                  railBackButtons.count == 1,
                  railBack.isHittable else {
                XCTFail("Expected one reachable BackButton for \(navigationTitle)")
                return
            }
            railBack.auditTap()
        }

        let departed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: destination
        )
        XCTAssertEqual(XCTWaiter.wait(for: [departed], timeout: 5), .completed,
                       "Back must dismiss \(navigationTitle)")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.injuryHistoryScreen].firstMatch.waitForExistence(timeout: 5),
                      "Back must return to Injury History")
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
        openPostureHistoryComparisonMenuAction()
        let metrics = app.staticTexts.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@",
            "posture-history-row-metric-count-", "8 metrics"
        ))
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

    func testP01CaptureFallbackRetryAndClose() throws {
        openPostureRoute("wellness-menu-posture")
        let error = app.staticTexts["posture-capture-error"].firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 10), "Simulator camera fallback should be visible")
        let retry = app.buttons["posture-capture-retry"].firstMatch
        XCTAssertTrue(retry.exists && retry.isHittable)
        VisualAudit.capture("P01 camera unavailable with retry and Close")

        retry.tap()
        let capture = app.buttons["posture-capture-button"].firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 5), "Retry returns to preparing controls")
        VisualAudit.capture("P01 preparing after retry without camera inference")

        app.buttons["posture-capture-close"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
            .waitForExistence(timeout: 5), "Close should return to Wellness")
    }

    private func openPostureRoute(_ menuIdentifier: String) {
        navigateToWellness()
        guard app.waitAndTapToolbarAction("Add record") else {
            XCTFail("Wellness Add record must be reachable before opening the posture route")
            return
        }
        let actionLabel: String
        switch menuIdentifier {
        case "wellness-menu-posture": actionLabel = "Posture Assessment"
        case "wellness-menu-realtime-posture": actionLabel = "Realtime Analysis"
        default:
            XCTFail("Unexpected posture route: \(menuIdentifier)")
            return
        }
        let action = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label == %@", menuIdentifier, actionLabel
        )).firstMatch
        guard action.waitForExistence(timeout: 5) else {
            XCTFail("The requested posture menu action must exist: \(actionLabel)")
            return
        }
        if !action.isHittable {
            // At MAX on the closed Duo, the fourth item sits below the native menu viewport.
            let menu = app.collectionViews.containing(.button, identifier: menuIdentifier).firstMatch
            for _ in 0..<4 {
                if action.isHittable { break }
                guard menu.exists, menu.isHittable else { break }
                let window = app.windows.firstMatch
                let viewport = menu.frame.intersection(window.frame).insetBy(dx: 8, dy: 8)
                guard !viewport.isNull, viewport.width > 0, viewport.height > 0 else { break }
                let towardLaterItems = action.frame.midY > viewport.midY
                let origin = window.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(
                    dx: viewport.midX - window.frame.minX,
                    dy: viewport.minY + viewport.height * (towardLaterItems ? 0.65 : 0.35) - window.frame.minY
                ))
                let end = origin.withOffset(CGVector(
                    dx: viewport.midX - window.frame.minX,
                    dy: viewport.minY + viewport.height * (towardLaterItems ? 0.35 : 0.65) - window.frame.minY
                ))
                start.press(forDuration: 0.05, thenDragTo: end,
                            withVelocity: XCUIGestureVelocity(rawValue: 80),
                            thenHoldForDuration: 0.35)
            }
        }
        guard action.isHittable else {
            XCTFail("The requested posture menu action must be visible: \(actionLabel)")
            return
        }
        action.auditTap()
    }

    func testP04SeededResultScoreMetricsMemoSaveAndRetake() throws {
        openSeededPostureResult()
        let score = app.descendants(matching: .any)["posture-result-score"].firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        XCTAssertEqual(score.label, "Posture score 86 out of 100")
        XCTAssertFalse(app.buttons["posture-result-capture-side"].exists,
                       "Full synthetic result should not request a side capture")
        VisualAudit.capture("P04 complete synthetic score and image cards")

        let metric = app.descendants(matching: .any)["posture-result-metric-forwardHead"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("posture-result-metric-forwardHead", maxSwipes: 12))
        XCTAssertTrue(metric.label.contains("Forward Head"), "Original metric name should remain")
        let frontalMetric = app.descendants(matching: .any)["posture-result-metric-shoulderAsymmetry"].firstMatch
        XCTAssertTrue(frontalMetric.exists && frontalMetric.label.contains("Shoulder"),
                      "Front and side synthetic metrics should both remain present")
        VisualAudit.capture("P04 original metric value and confidence")
        let memo = app.descendants(matching: .any)["posture-result-memo-field"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("posture-result-memo-field", maxSwipes: 12))
        XCTAssertTrue(memo.exists && memo.isHittable)
        XCTAssertTrue((memo.value as? String)?.contains("Visual audit fixture") == true,
                      "The synthetic memo should remain editable and populated")
        let save = app.buttons["posture-result-save"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("posture-result-save", maxSwipes: 8))
        XCTAssertTrue(save.isEnabled)
        VisualAudit.capture("P04 memo and Save Retake actions")
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
            .waitForExistence(timeout: 5), "Save should dismiss the result")
        VisualAudit.capture("P04 saved result returns to Wellness")

        openSeededPostureResult()
        let retake = app.buttons["posture-result-retake"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("posture-result-retake", maxSwipes: 12))
        retake.tap()
        XCTAssertTrue(app.buttons["posture-capture-button"].firstMatch.waitForExistence(timeout: 5),
                      "Retake returns to preparing controls")
        VisualAudit.capture("P04 Retake returns to capture preparation")
    }

    func testP04SeededResultAtMaximumAccessibilitySize() throws {
        openSeededPostureResult(maximumTextSize: true)
        let scroll = app.scrollViews["posture-result-screen"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let targets = ["posture-result-score", "posture-result-metric-forwardHead",
                       "posture-result-memo-field", "posture-result-save", "posture-result-retake"]
        for identifier in targets {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: 16),
                          "MAX result element must be reachable: \(identifier)")
            let element = app.descendants(matching: .any)[identifier].firstMatch
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
            if identifier == "posture-result-score" {
                XCTAssertTrue(viewport.contains(element.frame), "Entire MAX score card must fit")
            } else {
                XCTAssertTrue(viewport.intersects(element.frame), "MAX element must enter viewport: \(identifier)")
            }
            VisualAudit.capture("P04 MAX visible \(identifier)")
        }
    }

    private func openSeededPostureResult(maximumTextSize: Bool = false) {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-design-map-posture-result")
        if maximumTextSize {
            configuration.additionalArguments.append(contentsOf: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ])
        }
        launchApp(with: configuration)
        openPostureRoute("wellness-menu-posture")
        XCTAssertTrue(app.scrollViews["posture-result-screen"].firstMatch.waitForExistence(timeout: 10),
                      "Synthetic complete result should open")
    }

    func testP05HistoryLatestScoreFilterAndDetailReturn() throws {
        openHistory()
        let hero = app.descendants(matching: .any)["posture-history-latest-score"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Posture Score")
                      && hero.label.contains("86 / 100")
                      && hero.label.contains("8 metrics"),
                      "Combined hero must expose the stored score and metric count")
        XCTAssertFalse(app.staticTexts["Time for a new assessment"].exists,
                       "The newest fixture is one day old, so the seven-day reminder stays hidden")
        VisualAudit.capture("P05 latest recorded score and trend")

        let filter = app.buttons["Forward Head"].firstMatch
        reveal(filter)
        filter.auditTap()
        XCTAssertTrue(filter.isSelected, "The selected metric filter should be exposed to accessibility")
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics"))
        XCTAssertEqual(rows.count, 2, "Both seeded records remain in descending history")
        let row = rows.firstMatch
        reveal(row)
        row.auditTap()
        XCTAssertTrue(app.navigationBars["Assessment Detail"].waitForExistence(timeout: 5))
        let back = app.navigationBars["Assessment Detail"].buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable)
        back.auditTap()
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "Back returns to the same history")

        let latest = rows.firstMatch
        let cancelAlert = requestPostureHistoryDeletion(latest)
        cancelAlert.buttons["Cancel"].auditTap()
        XCTAssertEqual(rows.count, 2, "Cancel keeps both seeded assessments")

        let deleteLatestAlert = requestPostureHistoryDeletion(rows.firstMatch)
        deleteLatestAlert.buttons["Delete"].auditTap()
        let remainingScore = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "73 / 100"), object: hero
        )
        XCTAssertEqual(XCTWaiter.wait(for: [remainingScore], timeout: 5), .completed,
                       "Deleting the newest record reveals the original older score")
        let reminder = app.staticTexts["Time for a new assessment"].firstMatch
        XCTAssertTrue(reminder.waitForExistence(timeout: 5), "The remaining record is fourteen days old")
        XCTAssertEqual(rows.count, 1)
        reveal(reminder)
        VisualAudit.capture("P05 real remaining score and seven-day reminder")

        let deleteRemainingAlert = requestPostureHistoryDeletion(rows.firstMatch)
        deleteRemainingAlert.buttons["Delete"].auditTap()
        let empty = app.staticTexts["No Posture Assessments"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "Deleting the last fixture shows the empty state")
        XCTAssertFalse(hero.exists)
        VisualAudit.capture("P05 empty history after isolated fixture deletion")
    }

    func testP05HistoryLatestScoreAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openHistory(maxRevealAttempts: 36)
        let hero = app.descendants(matching: .any)["posture-history-latest-score"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Posture Score")
                      && hero.label.contains("86 / 100")
                      && hero.label.contains("8 metrics"),
                      "Combined hero must expose the stored score and metric count")
        let scroll = app.scrollViews["posture-history-screen"].firstMatch
        XCTAssertTrue(scroll.exists)
        XCTAssertTrue(scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
            .contains(hero.frame), "The complete latest-score hero must fit at maximum text size")
        VisualAudit.capture("P05 MAX latest recorded score")
    }

    private func requestPostureHistoryDeletion(_ row: XCUIElement) -> XCUIElement {
        reveal(row)
        row.press(forDuration: 1.1)
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "History context menu must offer Delete")
        delete.auditTap()
        let alert = app.alerts["Delete Assessment"].firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete must require confirmation")
        return alert
    }

    func testP07SymmetryKeepsSeededValuesAndUnits() throws {
        openSeededSymmetry()
        let scroll = app.scrollViews["posture-symmetry-screen"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for (metric, side, expected) in seededSymmetryValues {
            let id = "posture-symmetry-value-\(metric)-\(side)"
            let value = app.staticTexts[id].firstMatch
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(id, maxSwipes: 16),
                          "Seeded symmetry value must remain reachable: \(id)")
            XCTAssertEqual(value.label, expected, "Keep the recorded value and unit")
        }
        VisualAudit.capture("P07 three stored left-right metric pairs")
    }

    func testP07SymmetryValuesFitAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openSeededSymmetry()
        let scroll = app.scrollViews["posture-symmetry-screen"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for (metric, side, expected) in seededSymmetryValues {
            let id = "posture-symmetry-value-\(metric)-\(side)"
            let value = app.staticTexts[id].firstMatch
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(id, maxSwipes: 16),
                          "MAX symmetry value must remain reachable: \(id)")
            XCTAssertEqual(value.label, expected)
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 6, dy: 6)
            XCTAssertTrue(viewport.contains(value.frame), "The whole value and unit must fit: \(id)")
            VisualAudit.capture("P07 MAX \(metric) \(side) full value")
        }
    }

    private var seededSymmetryValues: [(String, String, String)] {
        [("shoulderAsymmetry", "left", "50.0 cm"), ("shoulderAsymmetry", "right", "48.0 cm"),
         ("hipAsymmetry", "left", "0.0 cm"), ("hipAsymmetry", "right", "-1.0 cm"),
         ("kneeAlignment", "left", "8.1°"), ("kneeAlignment", "right", "2.7°")]
    }

    private func openSeededSymmetry() {
        openHistory()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8 metrics")).firstMatch
        reveal(row)
        row.auditTap()
        let link = app.buttons["posture-symmetry-link"].firstMatch
        reveal(link)
        link.auditTap()
        XCTAssertTrue(app.scrollViews["posture-symmetry-screen"].firstMatch.waitForExistence(timeout: 5))
    }

    func testP02RealtimeFallbackAndP03ExerciseSelection() throws {
        openPostureRoute("wellness-menu-realtime-posture")
        let fallback = app.descendants(matching: .any)["realtime-camera-unavailable"].firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 10), "Simulator camera fallback should be visible")
        let retry = app.buttons["realtime-camera-retry"].firstMatch
        XCTAssertTrue(retry.exists && retry.isHittable)
        VisualAudit.capture("P02 camera unavailable and exercise entry")

        retry.tap()
        XCTAssertTrue(fallback.waitForExistence(timeout: 5), "Camera retry remains unavailable on simulator")
        let mode = app.buttons["realtime-exercise-picker-button"].firstMatch
        XCTAssertTrue(mode.exists && mode.isHittable, "Picker remains available without camera")
        mode.tap()
        let list = app.descendants(matching: .any)["posture-exercise-list"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let general = app.buttons["posture-exercise-general"].firstMatch
        XCTAssertTrue(general.isSelected, "General mode starts selected")
        VisualAudit.capture("P03 General Posture selected")

        let squat = app.buttons["posture-exercise-barbell-squat"].firstMatch
        XCTAssertTrue(squat.exists && squat.isHittable)
        squat.tap()
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertEqual(mode.value as? String, "barbell-squat")
        mode.tap()
        XCTAssertTrue(squat.waitForExistence(timeout: 5) && squat.isSelected)
        XCTAssertFalse(general.isSelected)
        VisualAudit.capture("P03 barbell squat selection retained on reopen")

        general.tap()
        XCTAssertEqual(mode.value as? String, "general")
        mode.tap()
        XCTAssertTrue(general.waitForExistence(timeout: 5) && general.isSelected)
        VisualAudit.capture("P03 General Posture restored")
        app.buttons["posture-exercise-close"].tap()
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        app.buttons["realtime-posture-close"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
            .waitForExistence(timeout: 5))
    }

    func testP03ExerciseListAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        openPostureRoute("wellness-menu-realtime-posture")
        app.buttons["realtime-exercise-picker-button"].tap()
        let list = app.descendants(matching: .any)["posture-exercise-list"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        VisualAudit.capture("P03 MAX General Posture and first exercise")
        let last = app.buttons["posture-exercise-lunge"].firstMatch
        XCTAssertTrue(revealExerciseRow(last, in: list), "Last exercise must fit in the visible list at MAX")
        VisualAudit.capture("P03 MAX final exercise reachable by scrolling")
        last.tap()
        let mode = app.buttons["realtime-exercise-picker-button"].firstMatch
        XCTAssertEqual(mode.value as? String, "lunge")
        mode.tap()
        let reopenedList = app.descendants(matching: .any)["posture-exercise-list"].firstMatch
        XCTAssertTrue(reopenedList.waitForExistence(timeout: 5))
        XCTAssertTrue(revealExerciseRow(last, in: reopenedList), "Selected final row must remain reachable")
        XCTAssertTrue(last.isSelected)
        VisualAudit.capture("P03 MAX final exercise selected on reopen")
        let close = app.buttons["posture-exercise-close"].firstMatch
        XCTAssertTrue(close.exists && close.isHittable
                      && app.windows.firstMatch.frame.contains(close.frame),
                      "MAX Close must fit outside the scrolling list")
        close.tap()
        XCTAssertTrue(reopenedList.waitForNonExistence(timeout: 5), "Close must dismiss the exercise list")
        XCTAssertTrue(mode.waitForExistence(timeout: 5) && mode.isHittable)
        XCTAssertEqual(mode.value as? String, "lunge", "Close must preserve the selected exercise")
    }

    private func revealExerciseRow(_ row: XCUIElement, in list: XCUIElement) -> Bool {
        for _ in 0..<12 {
            let viewport = list.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
            if row.exists && row.isHittable && viewport.contains(row.frame) { return true }
            if row.exists && row.frame.midY < viewport.midY {
                list.swipeDown(velocity: .slow)
            } else {
                list.swipeUp(velocity: .slow)
            }
        }
        let viewport = list.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
        return row.exists && row.isHittable && viewport.contains(row.frame)
    }

    func testP08ComparisonKeepsScoresDatesPanesAndPhotoZoom() throws {
        openSeededComparison()
        let photos = app.scrollViews["posture-comparison-photos-scroll"].firstMatch
        let metrics = app.scrollViews["posture-comparison-metrics-scroll"].firstMatch
        XCTAssertTrue(photos.waitForExistence(timeout: 5) && metrics.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["73"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["86"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["+13"].firstMatch.exists)
        for offset in [14, 1] {
            let date = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -offset, to: .now))
                .formatted(Date.FormatStyle.dateTime.month(.abbreviated).day()
                    .locale(Locale(identifier: "en_US")))
            XCTAssertTrue(app.staticTexts[date].firstMatch.exists, "Keep both fixture dates")
        }
        VisualAudit.capture("P08 actual older and newer score delta")

        let front = app.descendants(matching: .any)["posture-comparison-photo-front-older"].firstMatch
        XCTAssertTrue(front.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch
        for _ in 0..<12 {
            let viewport = photos.frame.intersection(window.frame).insetBy(dx: 6, dy: 6)
            let visible = front.frame.intersection(viewport)
            if front.isHittable && !visible.isNull && visible.width >= 24 && visible.height >= 24 {
                break
            }
            let startY: CGFloat = front.frame.midY > viewport.midY ? 0.65 : 0.35
            let endY: CGFloat = front.frame.midY > viewport.midY ? 0.35 : 0.65
            let start = photos.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            let end = photos.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
            start.press(forDuration: 0.05, thenDragTo: end,
                        withVelocity: XCUIGestureVelocity(rawValue: 80),
                        thenHoldForDuration: 0.35)
        }
        let visible = front.frame.intersection(
            photos.frame.intersection(window.frame).insetBy(dx: 6, dy: 6))
        guard front.isHittable && !visible.isNull && visible.width >= 24 && visible.height >= 24 else {
            XCTFail("Front photo must have a 24-point tappable area inside its own visible pane before opening zoom")
            return
        }
        let frontFrame = front.frame
        let tapPoint = front.coordinate(withNormalizedOffset: CGVector(
            dx: (visible.midX - frontFrame.minX) / frontFrame.width,
            dy: (visible.midY - frontFrame.minY) / frontFrame.height))
        tapPoint.auditTap()
        XCTAssertTrue(app.navigationBars["Front"].firstMatch.waitForExistence(timeout: 5))
        // Duo places the zoom Close control in the native Toolbar beside the
        // Front navigation bar; query its actual unique identity and viewport.
        let closeMatches = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "xmark", "Close"
        ))
        let close = closeMatches.firstMatch
        XCTAssertEqual(closeMatches.count, 1, "Front zoom must expose one Close control")
        XCTAssertTrue(close.exists && close.isEnabled && close.isHittable && window.frame.contains(close.frame),
                      "The whole Front zoom Close control must be visible")
        close.auditTap()
        XCTAssertFalse(app.navigationBars["Front"].firstMatch.exists, "Close dismisses the zoom route")
        XCTAssertTrue(photos.waitForExistence(timeout: 5), "Closing zoom returns to comparison")
        metrics.swipeUp(velocity: .slow)
        VisualAudit.capture("P08 lower metric comparison pane")
    }

    func testP08ComparisonAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openSeededComparison(maxRevealAttempts: 36)
        let photos = app.scrollViews["posture-comparison-photos-scroll"].firstMatch
        let metrics = app.scrollViews["posture-comparison-metrics-scroll"].firstMatch
        XCTAssertTrue(photos.waitForExistence(timeout: 5) && metrics.waitForExistence(timeout: 5))
        let navigationBar = app.navigationBars["Comparison"].firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        func visiblePhotoViewport() -> CGRect {
            let pane = photos.frame.intersection(app.windows.firstMatch.frame)
            let top = max(pane.minY + 4, navigationBar.frame.maxY + 4)
            return CGRect(x: pane.minX + 4, y: top,
                          width: max(0, pane.width - 8),
                          height: max(0, pane.maxY - top - 4))
        }
        for score in ["73", "86", "+13"] {
            let value = app.staticTexts[score].firstMatch
            XCTAssertTrue(value.waitForExistence(timeout: 5))
            for _ in 0..<16 {
                let viewport = visiblePhotoViewport()
                if value.isHittable && viewport.contains(value.frame) { break }
                let moveDown = value.frame.midY < viewport.midY
                let overflow = moveDown ? viewport.minY - value.frame.minY
                                        : value.frame.maxY - viewport.maxY
                let fraction = min(0.14, max(0.04, (overflow + 12) / max(photos.frame.height, 1)))
                let startY: CGFloat = moveDown ? 0.38 : 0.62
                let start = photos.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                let end = photos.coordinate(withNormalizedOffset: CGVector(
                    dx: 0.5, dy: moveDown ? startY + fraction : startY - fraction))
                start.press(forDuration: 0.05, thenDragTo: end,
                            withVelocity: XCUIGestureVelocity(rawValue: 80),
                            thenHoldForDuration: 0.35)
            }
            XCTAssertTrue(value.isHittable && visiblePhotoViewport().contains(value.frame),
                          "The whole score text must fit below navigation inside its photo pane: \(score)")
            VisualAudit.capture("P08 MAX visible comparison score \(score)")
        }
        metrics.swipeUp(velocity: .slow)
        XCTAssertTrue(metrics.isHittable, "MAX metric pane remains independently scrollable")
        VisualAudit.capture("P08 MAX score and two panes")
    }

    private func openPostureHistoryComparisonMenuAction() {
        let menu = app.buttons["posture-history-actions-menu"].firstMatch
        guard menu.waitForExistence(timeout: 5), menu.isHittable else {
            XCTFail("The explicit posture actions menu must be reachable")
            return
        }
        menu.auditTap()
        let compare = app.buttons["posture-history-compare-button"].firstMatch
        XCTAssertTrue(compare.waitForExistence(timeout: 5) && compare.isHittable)
        XCTAssertEqual(compare.label, "Compare")
        compare.auditTap()
    }

    private func openSeededComparison(maxRevealAttempts: Int = 18) {
        openHistory(maxRevealAttempts: maxRevealAttempts)
        openPostureHistoryComparisonMenuAction()
        let metrics = app.staticTexts.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@",
            "posture-history-row-metric-count-", "8 metrics"
        ))
        XCTAssertEqual(metrics.count, 2)
        for index in 0..<2 {
            let metric = metrics.element(boundBy: index)
            reveal(metric)
            metric.auditTap()
        }
        let selected = app.buttons["Compare Selected"].firstMatch
        reveal(selected)
        selected.auditTap()
        XCTAssertTrue(app.navigationBars["Comparison"].firstMatch.waitForExistence(timeout: 5))
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
        // Duo History has a vertical tab rail in both folded and open poses.
        // Keep the 90-point top protection; only shrink the bottom inset when
        // the actual rail geometry proves this is the short History viewport.
        let wellnessTab = app.buttons["tab-wellness"].firstMatch
        let sideRailHistory = scroll.identifier == "posture-history-screen"
            && scroll.frame.height <= 700 && wellnessTab.exists
            && wellnessTab.frame.width <= 60
            && wellnessTab.frame.minX >= scroll.frame.maxX - 80
        func visibleViewport() -> CGRect {
            let frame = scroll.frame.intersection(app.windows.firstMatch.frame)
                .insetBy(dx: 12, dy: 0)
            let top = frame.minY + 90
            let bottom = frame.maxY - (sideRailHistory ? 12 : 90)
            return CGRect(x: frame.minX, y: top, width: frame.width,
                          height: max(0, bottom - top))
        }
        for _ in 0..<maxAttempts {
            // Duo may report offscreen descendants as hittable. The target's
            // tap point must also lie inside the visible scroll viewport.
            let viewport = visibleViewport()
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
        let viewport = visibleViewport()
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
