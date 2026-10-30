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
