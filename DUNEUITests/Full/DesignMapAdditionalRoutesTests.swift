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
        VisualAudit.capture("Sleep prediction detail")
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

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.exists)
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
    }

    func testNotificationPersonalRecordsPush() throws {
        openNotificationDetail(title: "Personal Records Route Fixture",
                               screen: "activity-personal-records-detail-screen")
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
