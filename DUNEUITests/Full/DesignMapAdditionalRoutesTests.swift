@preconcurrency import XCTest

@MainActor
final class DesignMapAdditionalRoutesTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "--ui-design-map-sleep-prediction"]
    }

    func testHealthDataQAOpensFromToday() throws {
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

        let send = app.buttons["health-qa-send"].firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Health Q&A inspector should open")
        VisualAudit.capture("Health Q&A inspector")
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
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable, "The native back button should be usable")
        XCTAssertGreaterThanOrEqual(back.frame.width, 44)
        XCTAssertGreaterThanOrEqual(back.frame.height, 44)
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
    }

    func testNotificationDestinationUnavailable() throws {
        openNotificationDetail(title: "Unavailable Route Fixture",
                               screen: "notification-destination-unavailable-screen")
    }

    func testNotificationPersonalRecordsPush() throws {
        openNotificationDetail(title: "Personal Records Route Fixture",
                               screen: "activity-personal-records-detail-screen")
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
