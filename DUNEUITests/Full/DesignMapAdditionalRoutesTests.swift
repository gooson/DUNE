@preconcurrency import XCTest

@MainActor
final class DesignMapAdditionalRoutesTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "--ui-design-map-sleep-prediction"]
    }

    func testHealthDataQAOpensFromToday() throws {
        try openHealthQA(availableFixture: true, maximumAX: false)
        try assertAvailableHealthQA(checkDraft: true)
        try openHealthQA(availableFixture: false, maximumAX: false)
        try assertUnavailableHealthQA()
    }

    func testHealthDataQAAtMaximumAccessibilitySize() throws {
        try openHealthQA(availableFixture: true, maximumAX: true)
        try assertAvailableHealthQA(checkDraft: false)
        try openHealthQA(availableFixture: false, maximumAX: true)
        try assertUnavailableHealthQA()
    }

    private func openHealthQA(availableFixture: Bool, maximumAX: Bool) throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(availableFixture
            ? "--ui-health-qa-available-fixture" : "--ui-health-qa-unavailable-fixture")
        if maximumAX {
            configuration.additionalArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        launchApp(with: configuration)
        navigateToDashboard()
        let briefingDismiss = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        if briefingDismiss.exists {
            briefingDismiss.auditTap()
        }

        let cardID = "dashboard-health-qa-card"
        XCTAssertTrue(app.scrollToElementIfNeeded(cardID, maxSwipes: 18), "Health Q&A card should be reachable")
        let card = app.descendants(matching: .any)[cardID].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.auditTap()
        XCTAssertTrue(app.buttons["health-qa-done"].firstMatch.waitForExistence(timeout: 5))
    }

    private func assertAvailableHealthQA(checkDraft: Bool) throws {
        let emptyScroll = app.scrollViews["health-qa-empty-scroll"].firstMatch
        XCTAssertTrue(emptyScroll.waitForExistence(timeout: 5), "The available inspector needs a scrollable empty state")
        XCTAssertTrue(app.revealTextBody("health-qa-overview-body", in: emptyScroll))
        XCTAssertEqual(app.staticTexts["health-qa-overview-body"].firstMatch.label,
                       "Answers are informational and based on your recent DUNE health data.")
        XCTAssertTrue(app.revealTextBody("health-qa-overview-guide", in: emptyScroll))
        XCTAssertEqual(app.staticTexts["health-qa-overview-guide"].firstMatch.label,
                       "Try one of these questions to get started.")
        VisualAudit.capture("T17 available overview")
        let prompt = app.buttons["health-qa-prompt-sleep"].firstMatch
        XCTAssertTrue(app.revealFullyVisible("health-qa-prompt-sleep", in: emptyScroll))
        XCTAssertEqual(prompt.label, "How has my sleep looked this week?")
        XCTAssertTrue(prompt.isHittable)
        VisualAudit.capture("T17 available suggested prompt")
        prompt.auditTap()
        let messages = app.scrollViews["health-qa-message-list"].firstMatch
        XCTAssertTrue(messages.waitForExistence(timeout: 8), "The prompt should create a conversation")
        XCTAssertTrue(app.staticTexts["How has my sleep looked this week?"].firstMatch.exists)
        let fallback = app.staticTexts["health-qa-fallback-label"].firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 12), "The deterministic fixture should complete its reply")
        XCTAssertEqual(app.staticTexts["health-qa-answer-body"].firstMatch.label, "UI test response.")
        XCTAssertTrue(app.revealFullyVisible("health-qa-fallback-label", in: messages))
        VisualAudit.capture("T17 available answer and composer")

        let input = app.descendants(matching: .any)["health-qa-input"].firstMatch
        let send = app.buttons["health-qa-send"].firstMatch
        XCTAssertTrue(input.exists && send.exists)
        XCTAssertFalse(send.isEnabled, "An empty draft must not be sent")
        if checkDraft {
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            input.auditTap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                          "The software keyboard should open for a question draft")
            VisualAudit.capture("T17 focused composer and software keyboard")
            input.typeText("How was my recovery?")
            XCTAssertTrue(send.isEnabled)
            send.auditTap()
            XCTAssertTrue(app.staticTexts["How was my recovery?"].firstMatch.waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts["health-qa-fallback-label"].firstMatch.waitForExistence(timeout: 12))
        }
        try browseHealthRecordsAndReturn()
        dismissHealthQA(captureReturn: false)
    }

    private func assertUnavailableHealthQA() throws {
        let scroll = app.scrollViews["health-qa-unavailable-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Unsupported hardware needs a readable explanation")
        XCTAssertTrue(app.revealTextBody("health-qa-unavailable-title", in: scroll))
        XCTAssertEqual(app.staticTexts["health-qa-unavailable-title"].firstMatch.label,
                       "Health Q&A requires Apple Intelligence on a supported device.")
        XCTAssertTrue(app.revealTextBody("health-qa-unavailable-body", in: scroll))
        XCTAssertEqual(app.staticTexts["health-qa-unavailable-body"].firstMatch.label,
                       "This feature uses on-device Foundation Models, so it only works on compatible hardware.")
        VisualAudit.capture("T17 unavailable explanation")
        let inlineBrowse = scroll.buttons["health-qa-browse-records"].firstMatch
        for _ in 0..<8 where !inlineBrowse.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(inlineBrowse.isHittable, "The unavailable state's inline Browse route must be reachable")
        VisualAudit.capture("T17 unavailable Browse route")
        try browseHealthRecordsAndReturn(preferred: inlineBrowse, captureQuery: false)
        dismissHealthQA()
    }

    private func browseHealthRecordsAndReturn(preferred: XCUIElement? = nil,
                                              captureQuery: Bool = true) throws {
        let browse: XCUIElement
        if let preferred {
            browse = preferred
        } else {
            let candidates = app.buttons.matching(identifier: "health-qa-browse-records").allElementsBoundByIndex
            browse = try XCTUnwrap(candidates.first(where: { $0.exists && $0.isHittable }),
                                   "A visible Browse records route should remain available")
        }
        browse.auditTap()
        let query = app.descendants(matching: .any)["health-query-screen"].firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 8))
        if captureQuery { VisualAudit.capture("T17 browse records") }
        let queryDone = app.buttons["health-query-done"].firstMatch
        XCTAssertTrue(queryDone.waitForExistence(timeout: 5))
        queryDone.auditTap()
        XCTAssertTrue(query.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["health-qa-done"].firstMatch.waitForExistence(timeout: 5))
    }

    private func dismissHealthQA(captureReturn: Bool = true) {
        let done = app.buttons["health-qa-done"].firstMatch
        XCTAssertTrue(done.isHittable)
        done.auditTap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-health-qa-card"].firstMatch.exists)
        if captureReturn { VisualAudit.capture("T17 returned to Today") }
    }

    func testSleepPredictionOpensFromWellness() throws {
        openH03SleepPrediction()
        VisualAudit.capture("Sleep prediction detail initial viewport")
        addScreenshotAttachment(named: "H03 sleep prediction initial viewport")
        let hero = app.descendants(matching: .any)["sleep-prediction-hero"].firstMatch
        XCTAssertTrue(hero.exists)
        XCTAssertTrue(h03ScoreLabel().label.contains("Sleep score 78"),
                      "The fixture score should remain in the H03 hero")
        XCTAssertEqual(app.staticTexts["sleep-prediction-hero-status"].label, "Excellent")
        XCTAssertEqual(app.staticTexts["sleep-prediction-hero-guide"].label,
                       "Great conditions for restful sleep")
        XCTAssertTrue(app.staticTexts["sleep-prediction-confidence-label"].label.contains("Medium"))
        XCTAssertEqual(app.staticTexts["sleep-prediction-factor-detail-recentSleepPattern"].label,
                       "Recent sleep has been consistent")
        XCTAssertEqual(app.staticTexts["sleep-prediction-factor-detail-conditionLevel"].label,
                       "Today's condition is steady")
        XCTAssertTrue(app.staticTexts["Keep a regular bedtime tonight"].exists)
        h03TapNativeBack()
        XCTAssertTrue(app.descendants(matching: .any)["wellness-sleep-prediction-detail-screen"]
            .firstMatch.waitForNonExistence(timeout: 5))
    }

    func testSleepPredictionConfidenceUsesActualLowMediumHighFixture() throws {
        for (confidence, expectedLabel) in [
            ("low", "Low Confidence"),
            ("medium", "Medium Confidence"),
            ("high", "High Confidence")
        ] {
            var configuration = launchConfiguration
            configuration.additionalEnvironment["DUNE_UI_SLEEP_PREDICTION_CONFIDENCE"] = confidence
            launchApp(with: configuration)
            openH03SleepPrediction()
            VisualAudit.capture("Sleep prediction \(confidence) confidence initial viewport")
            addScreenshotAttachment(named: "H03 sleep prediction \(confidence) confidence")

            XCTAssertEqual(app.staticTexts["sleep-prediction-confidence-label"].label, expectedLabel)
            XCTAssertTrue(h03ScoreLabel().label.contains("Sleep score 78"))
            XCTAssertEqual(app.staticTexts["sleep-prediction-hero-status"].label, "Excellent")
            XCTAssertEqual(app.staticTexts["sleep-prediction-factor-detail-recentSleepPattern"].label,
                           "Recent sleep has been consistent")
            XCTAssertEqual(app.staticTexts["sleep-prediction-factor-detail-conditionLevel"].label,
                           "Today's condition is steady")
            XCTAssertTrue(app.staticTexts["Keep a regular bedtime tonight"].exists)
            h03TapNativeBack()
        }
    }

    func testSleepPredictionDarkMaximumAccessibilityKeepsContentReachable() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-test-style", "dark",
                                              "-UIPreferredContentSizeCategoryName",
                                              "UICTContentSizeCategoryAccessibilityXXXL"]
        launchApp(with: configuration)
        openH03SleepPrediction()

        let hero = app.descendants(matching: .any)["sleep-prediction-hero"].firstMatch
        XCTAssertTrue(hero.exists)
        XCTAssertTrue(h03RevealReadable(h03ScoreLabel()), "The score hero should be readable")
        XCTAssertTrue(h03ScoreLabel().label.contains("Sleep score 78"))
        XCTAssertTrue(h03RevealReadable(app.staticTexts["sleep-prediction-hero-status"].firstMatch))
        XCTAssertTrue(h03RevealReadable(app.staticTexts["sleep-prediction-hero-guide"].firstMatch))
        let confidence = app.staticTexts["sleep-prediction-confidence-label"].firstMatch
        XCTAssertTrue(h03RevealReadable(confidence), "Actual confidence should be readable")
        XCTAssertTrue(confidence.label.contains("Medium"))
        VisualAudit.capture("Sleep prediction dark maximum AX hero and confidence")

        for id in ["sleep-prediction-factor-title-recentSleepPattern",
                   "sleep-prediction-factor-detail-recentSleepPattern",
                   "sleep-prediction-factor-title-conditionLevel",
                   "sleep-prediction-factor-detail-conditionLevel"] {
            XCTAssertTrue(h03RevealReadable(app.staticTexts[id].firstMatch), "\(id) should be reachable")
        }
        VisualAudit.capture("Sleep prediction dark maximum AX factors")
        XCTAssertTrue(h03RevealReadable(app.staticTexts["Keep a regular bedtime tonight"].firstMatch),
                      "The original tip should be reachable")
        VisualAudit.capture("Sleep prediction dark maximum AX tip")
        h03TapNativeBack()
        XCTAssertTrue(app.descendants(matching: .any)["wellness-sleep-prediction-detail-screen"]
            .firstMatch.waitForNonExistence(timeout: 5))
    }

    private func openH03SleepPrediction() {
        navigateToWellness()
        let sectionID = "wellness-sleep-prediction-card"
        XCTAssertTrue(app.scrollToElementIfNeeded(sectionID), "Sleep prediction card should be reachable")
        let section = app.descendants(matching: .any)[sectionID].firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        let link = app.buttons["wellness-sleep-prediction-detail-link"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Sleep prediction should be tappable")
        link.auditTap()

        let detail = app.descendants(matching: .any)["wellness-sleep-prediction-detail-screen"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Sleep prediction detail should open")
    }

    private func h03RevealReadable(_ element: XCUIElement) -> Bool {
        let scroll = app.scrollViews["wellness-sleep-prediction-detail-screen"].firstMatch
        guard scroll.exists else { return false }
        for attempt in 0..<10 {
            if element.exists {
                let frame = element.frame
                let window = app.windows.firstMatch.frame
                let nav = app.navigationBars.firstMatch
                let tab = app.tabBars.firstMatch
                let top = max(window.minY, nav.exists ? nav.frame.maxY : window.minY)
                let bottom = tab.exists && tab.isHittable && tab.frame.minY > window.midY
                    ? min(window.maxY, tab.frame.minY) : window.maxY
                if frame.minX >= window.minX && frame.maxX <= window.maxX &&
                    frame.minY >= top && frame.maxY <= bottom && element.isHittable {
                    return true
                }
            }
            if attempt < 9 { scroll.swipeUp() }
        }
        return false
    }

    private func h03ScoreLabel() -> XCUIElement {
        app.descendants(matching: .any)["sleep-prediction-hero-score"].firstMatch
    }

    private func h03TapNativeBack() {
        let railBack = app.buttons["BackButton"].firstMatch
        let usesNativeRail = railBack.exists && railBack.isHittable
        let back = usesNativeRail ? railBack : app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5) && back.isHittable,
                      "The native back button should be usable")
        if !usesNativeRail {
            XCTAssertGreaterThanOrEqual(back.frame.width, 44)
            XCTAssertGreaterThanOrEqual(back.frame.height, 44)
        }
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(back.frame.minX, window.minX)
        XCTAssertLessThanOrEqual(back.frame.maxX, window.maxX)
        XCTAssertGreaterThanOrEqual(back.frame.minY, window.minY)
        XCTAssertLessThanOrEqual(back.frame.maxY, window.maxY)
        back.tap()
    }
}

@MainActor
final class DesignMapNotificationDetailTests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-design-map-notification-details"]
    }

    func testNotificationMessageDetail() throws {
        openNotificationDetail(title: "Message Route Fixture",
                               screen: "notification-message-detail-screen")

        let title = app.staticTexts["notification-message-title"].firstMatch
        let body = app.staticTexts["notification-message-body"].firstMatch
        XCTAssertEqual(title.label, "Message Route Fixture")
        XCTAssertEqual(body.label, "A notification message that opens its in-app detail.")
        addScreenshotAttachment(named: "T12 notification message detail verified")
        VisualAudit.capture("T12 notification message detail verified")

        let railBack = app.buttons["BackButton"].firstMatch
        let backButton = railBack.exists && railBack.isHittable
            ? railBack : app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "The native Back control should exist")
        XCTAssertTrue(backButton.isHittable, "The native Back control should be tappable")
        backButton.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 8))
    }

    func testNotificationMessageDetailDarkMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openNotificationDetail(title: "Message Route Fixture",
                               screen: "notification-message-detail-screen")

        let scroll = app.scrollViews["notification-message-detail-screen"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 8), "The front detail scroll should exist")
        let title = app.staticTexts["notification-message-title"].firstMatch
        let body = app.staticTexts["notification-message-body"].firstMatch
        XCTAssertEqual(title.label, "Message Route Fixture")
        XCTAssertEqual(body.label, "A notification message that opens its in-app detail.")

        revealDetailText(title, in: scroll, position: .whole)
        XCTAssertTrue(title.isHittable, "The complete payload title should be readable")
        addScreenshotAttachment(named: "T12 dark maximum text title")
        VisualAudit.capture("T12 dark maximum text title")

        revealDetailText(body, in: scroll, position: .start)
        addScreenshotAttachment(named: "T12 dark maximum text body start")
        revealDetailText(body, in: scroll, position: .end)
        addScreenshotAttachment(named: "T12 dark maximum text body end")
        VisualAudit.capture("T12 dark maximum text body end")

        let backButton = app.navigationBars["Notification"].buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "The native Back control should exist")
        XCTAssertTrue(backButton.isHittable, "The native Back control should be tappable")
        XCTAssertGreaterThanOrEqual(backButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(backButton.frame.height, 44)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(backButton.frame),
                      "The native Back control should fit inside the window")
        backButton.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 8), "Back should return to the notification hub")
    }

    private enum DetailTextPosition { case whole, start, end }

    private func detailViewport(for scroll: XCUIElement) -> CGRect {
        let scrollFrame = scroll.frame
        var viewport = scrollFrame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 0)
        let navigationBar = app.navigationBars["Notification"].firstMatch
        if navigationBar.exists && navigationBar.frame.maxY < scrollFrame.midY {
            let bottom = viewport.maxY
            viewport.origin.y = max(viewport.minY, navigationBar.frame.maxY + 4)
            viewport.size.height = max(0, bottom - viewport.minY)
        }
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists && tabBar.isHittable && tabBar.frame.minY > scrollFrame.midY {
            viewport.size.height = max(0, min(viewport.maxY, tabBar.frame.minY - 4) - viewport.minY)
        }
        return viewport
    }

    private func revealDetailText(_ element: XCUIElement, in scroll: XCUIElement,
                                  position: DetailTextPosition) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = detailViewport(for: scroll)
            let frame = element.frame
            let horizontalFit = frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
            let reached: Bool
            switch position {
            case .whole:
                reached = viewport.contains(frame) && element.isHittable
            case .start:
                reached = horizontalFit && frame.minY >= viewport.minY
                    && frame.intersection(viewport).height >= 24
            case .end:
                reached = horizontalFit && frame.maxY <= viewport.maxY
                    && frame.intersection(viewport).height >= 24
            }
            if reached { return }

            let moveUp: Bool
            switch position {
            case .whole, .start: moveUp = frame.minY >= viewport.midY
            case .end: moveUp = frame.maxY > viewport.maxY
            }
            let startY = moveUp ? viewport.maxY - 24 : viewport.minY + 24
            let endY = moveUp ? viewport.minY + 36 : viewport.maxY - 36
            let start = scroll.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (startY - scroll.frame.minY) / scroll.frame.height))
            let end = scroll.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (endY - scroll.frame.minY) / scroll.frame.height))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let viewport = detailViewport(for: scroll)
        let frame = element.frame
        XCTAssertGreaterThan(viewport.height, 72, "The detail should have a readable viewport")
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX, "Text should fit horizontally")
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX, "Text should fit horizontally")
        switch position {
        case .whole:
            XCTAssertTrue(viewport.contains(frame) && element.isHittable,
                          "The entire title should be visible and hittable")
        case .start:
            XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY)
            XCTAssertGreaterThanOrEqual(frame.intersection(viewport).height, 24)
        case .end:
            XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY)
            XCTAssertGreaterThanOrEqual(frame.intersection(viewport).height, 24)
        }
    }

    func testNotificationDestinationUnavailable() throws {
        openNotificationDetail(title: "Unavailable Route Fixture",
                               screen: "notification-destination-unavailable-screen")
        XCTAssertTrue(app.staticTexts["Destination Unavailable"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts[
            "Could not find where this notification should open. Check your notification settings."
        ].firstMatch.exists)
        let identifier = t13UnavailableIdentifier()
        XCTAssertNotNil(UUID(uuidString: String(identifier.label.dropFirst(4))),
                        "The footer should show the actual inbox UUID")
        let back = app.buttons["notification-destination-unavailable-back-button"].firstMatch
        XCTAssertTrue(back.exists)
        addScreenshotAttachment(named: "T13 unavailable destination verified before Back")
        VisualAudit.capture("T13 unavailable destination verified before Back")
        back.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 8))
    }

    func testNotificationDestinationUnavailableDarkMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openNotificationDetail(title: "Unavailable Route Fixture",
                               screen: "notification-destination-unavailable-screen")

        let scroll = app.scrollViews["notification-destination-unavailable-screen"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 8), "The front unavailable-detail scroll should exist")
        let title = app.staticTexts["Destination Unavailable"].firstMatch
        let explanation = app.staticTexts[
            "Could not find where this notification should open. Check your notification settings."
        ].firstMatch
        let identifier = t13UnavailableIdentifier()
        XCTAssertEqual(title.label, "Destination Unavailable")
        XCTAssertEqual(explanation.label,
                       "Could not find where this notification should open. Check your notification settings.")
        XCTAssertNotNil(UUID(uuidString: String(identifier.label.dropFirst(4))),
                        "The footer should show the actual inbox UUID")

        t13RevealUnavailable(title, in: scroll, position: .whole)
        addScreenshotAttachment(named: "T13 dark maximum text unavailable title")
        VisualAudit.capture("T13 dark maximum text unavailable title")
        t13RevealUnavailable(explanation, in: scroll, position: .start)
        addScreenshotAttachment(named: "T13 dark maximum text explanation start")
        t13RevealUnavailable(explanation, in: scroll, position: .end)
        addScreenshotAttachment(named: "T13 dark maximum text explanation end")

        let back = app.buttons["notification-destination-unavailable-back-button"].firstMatch
        t13RevealUnavailable(back, in: scroll, position: .whole)
        XCTAssertTrue(back.isHittable, "Go Back should be tappable")
        XCTAssertGreaterThanOrEqual(back.frame.width, 44)
        XCTAssertGreaterThanOrEqual(back.frame.height, 44)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(back.frame),
                      "Go Back should fit inside the window")
        addScreenshotAttachment(named: "T13 dark maximum text Go Back")
        t13RevealUnavailable(identifier, in: scroll, position: .whole)
        addScreenshotAttachment(named: "T13 dark maximum text inbox ID")
        VisualAudit.capture("T13 dark maximum text inbox ID before Back")

        t13RevealUnavailable(back, in: scroll, position: .whole)
        back.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 8), "Go Back should return to the notification hub")
    }

    private enum T13UnavailablePosition { case whole, start, end }

    private func t13UnavailableIdentifier() -> XCUIElement {
        let identifier = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "ID: ")
        ).firstMatch
        XCTAssertTrue(identifier.waitForExistence(timeout: 5), "The inbox ID footer should exist")
        return identifier
    }

    private func t13UnavailableViewport(for scroll: XCUIElement) -> CGRect {
        let scrollFrame = scroll.frame
        var viewport = scrollFrame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 0)
        let navigationBar = app.navigationBars["Notification"].firstMatch
        if navigationBar.exists && navigationBar.frame.maxY < scrollFrame.midY {
            let bottom = viewport.maxY
            viewport.origin.y = max(viewport.minY, navigationBar.frame.maxY + 4)
            viewport.size.height = max(0, bottom - viewport.minY)
        }
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists && tabBar.isHittable && tabBar.frame.minY > scrollFrame.midY {
            viewport.size.height = max(0, min(viewport.maxY, tabBar.frame.minY - 4) - viewport.minY)
        }
        return viewport
    }

    private func t13RevealUnavailable(_ element: XCUIElement, in scroll: XCUIElement,
                                      position: T13UnavailablePosition) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = t13UnavailableViewport(for: scroll)
            XCTAssertGreaterThan(viewport.height, 72, "The detail should have a readable viewport")
            let frame = element.frame
            let horizontalFit = frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
            let reached: Bool
            switch position {
            case .whole:
                reached = viewport.contains(frame) && element.isHittable
            case .start:
                reached = horizontalFit && frame.minY >= viewport.minY
                    && frame.intersection(viewport).height >= 24
            case .end:
                reached = horizontalFit && frame.maxY <= viewport.maxY
                    && frame.intersection(viewport).height >= 24
            }
            if reached { return }

            let moveUp: Bool
            switch position {
            case .whole, .start: moveUp = frame.minY >= viewport.midY
            case .end: moveUp = frame.maxY > viewport.maxY
            }
            let startY = moveUp ? viewport.maxY - 24 : viewport.minY + 24
            let endY = moveUp ? viewport.minY + 36 : viewport.maxY - 36
            let start = scroll.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (startY - scroll.frame.minY) / scroll.frame.height))
            let end = scroll.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (endY - scroll.frame.minY) / scroll.frame.height))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let viewport = t13UnavailableViewport(for: scroll)
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX, "Content should fit horizontally")
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX, "Content should fit horizontally")
        switch position {
        case .whole:
            XCTAssertTrue(viewport.contains(frame) && element.isHittable,
                          "The whole title, control, or footer should be visible")
        case .start:
            XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY)
            XCTAssertGreaterThanOrEqual(frame.intersection(viewport).height, 24)
        case .end:
            XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY)
            XCTAssertGreaterThanOrEqual(frame.intersection(viewport).height, 24)
        }
    }

    func testNotificationRewardHelp() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        launchApp(with: configuration)
        openNotificationDetail(title: "Personal Records Route Fixture",
                               screen: "activity-personal-records-detail-screen")
        let info = app.buttons["activity-personal-records-reward-info"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-personal-records-reward-info", maxSwipes: 30),
                      "Notification wrapper must load an actually eligible reward section")
        XCTAssertTrue(info.isHittable); info.tap()
        let sheet = app.scrollViews["activity-personal-records-reward-info-sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.staticTexts.matching(NSPredicate(format: "label == %@", "How Rewards Work")).firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("A21 notification reward help")
        let handles = app.buttons.matching(NSPredicate(format: "label IN %@", ["Sheet Grabber", "Sheet grabber", "시트 손잡이"]))
        XCTAssertEqual(handles.count, 1)
        let handle = handles.element(boundBy: 0), window = app.windows.firstMatch
        XCTAssertTrue(handle.exists && handle.isHittable && window.frame.contains(handle.frame))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: handle.frame.midX - window.frame.minX, dy: window.frame.height - 4))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: 1000), thenHoldForDuration: 0)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10))
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        let railBack = app.buttons["BackButton"].firstMatch
        let back = railBack.exists && railBack.isHittable ? railBack : app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5) && back.isHittable)
        XCTAssertFalse(back.frame.isEmpty)
        XCTAssertTrue(window.frame.contains(back.frame), "Native Back must fit the active window")
        back.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("A21 notification reward return")
    }

    func testNotificationPersonalRecordsPush() throws {
        openNotificationDetail(title: "Personal Records Route Fixture",
                               screen: "activity-personal-records-detail-screen")
        let picker = app.descendants(matching: .any)["activity-personal-records-period-picker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "The notification destination should finish loading")
        let pace = app.buttons["activity-personal-records-kind-fastestPace"].firstMatch
        XCTAssertTrue(pace.waitForExistence(timeout: 10))
        let chips = app.scrollViews["activity-personal-records-chip-bar"].firstMatch
        XCTAssertTrue(chips.waitForExistence(timeout: 5))
        for _ in 0..<6 where !pace.isHittable { chips.swipeLeft() }
        XCTAssertTrue(pace.isHittable)
        pace.tap()
        let sixMonths = app.buttons["activity-personal-records-period-6M"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-personal-records-period-6M", maxSwipes: 8))
        sixMonths.tap()
        XCTAssertTrue(sixMonths.isSelected)
        let scroll = app.scrollViews["activity-personal-records-detail-screen"].firstMatch
        let best = app.staticTexts["activity-personal-records-best-value"].firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 10))
        let hero = app.descendants(matching: .any)["activity-personal-records-current-best"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        for _ in 0..<12 where !scroll.frame.intersection(app.windows.firstMatch.frame).contains(hero.frame) {
            if hero.frame.midY < scroll.frame.midY { scroll.swipeDown(velocity: .slow) }
            else { scroll.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(scroll.frame.intersection(app.windows.firstMatch.frame).contains(hero.frame),
                      "The normal-size canonical hero should be fully visible")
        VisualAudit.capture("Personal Records T16 fastest pace six-month hero")
        addScreenshotAttachment(named: "Personal Records T16 fastest pace six-month hero")

        // Duo exposes the system rail outside navigationBars; other devices use the navigation bar.
        let railBack = app.buttons["BackButton"].firstMatch
        let navigationBack = app.navigationBars.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@ OR label == %@", "BackButton", "Back", "Notifications")
        ).firstMatch
        let back = railBack.exists && railBack.isHittable ? railBack : navigationBack
        XCTAssertTrue(back.waitForExistence(timeout: 5) && back.isHittable,
                      "The native back button should remain usable")
        back.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-personal-records-detail-screen"].firstMatch
            .waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 5), "Back should return to the notification hub")
    }

    func testNotificationSleepDetailLoadsSharedPrediction() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-design-map-sleep-prediction")
        launchApp(with: configuration)
        openNotificationDetail(title: "Bedtime Route Fixture",
                               screen: "notification-sleep-detail-screen")

        let score = app.descendants(matching: .any)["sleep-prediction-hero-score"].firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 10), "The notification route should load H03 prediction")
        XCTAssertTrue(score.label.contains("Sleep score 78"))
        XCTAssertEqual(app.staticTexts["sleep-prediction-hero-guide"].label,
                       "Great conditions for restful sleep")
        XCTAssertEqual(app.staticTexts["sleep-prediction-confidence-label"].label,
                       "Medium Confidence")
        VisualAudit.capture("T15 loaded H03 sleep prediction initial viewport")
        addScreenshotAttachment(named: "T15 loaded H03 sleep prediction initial viewport")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable, "The native back button should remain usable")
        back.tap()
        XCTAssertTrue(app.descendants(matching: .any)["notification-sleep-detail-screen"].firstMatch
            .waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 5), "Back should return to the Today notification hub")
        let tabBar = app.tabBars.firstMatch
        let today = tabBar.buttons["Today"].firstMatch
        if tabBar.exists && today.exists {
            XCTAssertTrue(today.isSelected, "Today should remain selected after the in-hub route")
        }
    }

    private func openNotificationDetail(title: String, screen: String) {
        navigateToDashboard()
        let briefingDismiss = app.buttons[AXID.dashboardMorningBriefingDismiss].firstMatch
        if briefingDismiss.exists { briefingDismiss.auditTap() }
        let notifications = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notifications.waitForExistence(timeout: 10))
        notifications.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 8))
        let row = app.staticTexts[title].firstMatch
        let list = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        for _ in 0..<16 where !row.exists { list.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 3), "Notification row should exist: \(title)")
        row.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[screen].firstMatch.waitForExistence(timeout: 8))
        VisualAudit.capture(title)
    }
}
