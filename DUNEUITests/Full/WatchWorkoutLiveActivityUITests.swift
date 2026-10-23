@preconcurrency import XCTest

@MainActor
final class WatchWorkoutLiveActivityUITests: UITestBaseCase {
    // These tests inspect SpringBoard, so the app-navigation setup in the base
    // class is deliberately skipped. The base teardown still ends the app.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunningNotificationCenterPresentation() {
        captureNotificationCenter(phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"])
    }

    func testPausedNotificationCenterPresentation() {
        captureNotificationCenter(phase: "paused", expectedStatuses: ["Paused", "일시 정지", "一時停止"])
    }

    private func captureNotificationCenter(phase: String, expectedStatuses: [String]) {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-watch-live-activity", phase,
            "--ui-test-theme", "desertWarm",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Pull from the left side of the status bar, away from Dynamic Island.
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.01))
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.72))
        top.press(forDuration: 0.05, thenDragTo: bottom)

        let title = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Outdoor Run"))
            .firstMatch
        let didFindTitle = title.waitForExistence(timeout: 15)
        // Extensions use SpringBoard's language, independent of the app launch locale.
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "허용", "許可"])).firstMatch
        if allow.waitForExistence(timeout: 2) { allow.tap() }

        let activity = springboard.otherElements.containing(.staticText, identifier: "Outdoor Run")
            .allElementsBoundByIndex
            .filter { $0.frame.width > 250 && $0.frame.height > 70 && $0.frame.height < 220 }
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        let hierarchy = springboard.debugDescription
        attachEvidence(phase: phase, hierarchy: hierarchy, activity: activity)

        XCTAssertTrue(didFindTitle, "SpringBoard should display the seeded workout")
        XCTAssertTrue(hierarchy.contains("Outdoor Run"), "Workout title should appear in system UI")
        XCTAssertTrue(expectedStatuses.contains(where: hierarchy.contains), "Localized workout status should appear in system UI")
        XCTAssertTrue(hierarchy.contains("142"), "Heart rate should appear in system UI")
        XCTAssertTrue(hierarchy.contains("86"), "Active calories should appear in system UI")
    }

    private func attachEvidence(phase: String, hierarchy: String, activity: XCUIElement?) {
        // Capture only our Live Activity; unrelated notifications may exist on the simulator.
        XCTAssertNotNil(activity, "The system should expose the workout activity container")
        if let activity {
            let screenshot = XCTAttachment(screenshot: activity.screenshot())
            screenshot.name = "WLA01-\(phase)-notification-center"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }

        let hierarchyAttachment = XCTAttachment(string: hierarchy)
        hierarchyAttachment.name = "WLA01-\(phase)-springboard-hierarchy"
        hierarchyAttachment.lifetime = .keepAlways
        add(hierarchyAttachment)
    }
}

@MainActor
final class SystemWidgetDesignTests: UITestBaseCase {
    func testSystemDUNETodayWidgetFamilies() throws {
        var configuration = launchConfiguration
        configuration.shouldSeedMockData = true
        configuration.scenario = .defaultSeeded
        configuration.additionalArguments += [
            "--ui-test-theme", "desertWarm", "--ui-test-style", "light",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        launchApp(with: configuration)
    
        // Let each production view model write its real seeded score to the App Group.
        for (tab, ringID) in [
            ("Today", "dashboard-hero-ring"),
            ("Activity", "activity-hero-ring"),
            ("Wellness", "wellness-hero-ring")
        ] {
            app.navigateToTab(tab)
            XCTAssertTrue(app.descendants(matching: .any)[ringID].firstMatch.waitForExistence(timeout: 12),
                          "\(tab) should calculate its score before opening WidgetKit")
        }
    
        navigateToDashboard()
        addScreenshotAttachment(named: "Desert Today after latest integration")
    
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func attachHierarchy(_ stage: String) {
            let attachment = XCTAttachment(string: springboard.debugDescription)
            attachment.name = "DUNE widget system hierarchy - \(stage)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func visible(_ labels: [String]) -> XCUIElement? {
            let predicate = NSPredicate(format: "label IN %@", labels)
            return springboard.descendants(matching: .any).matching(predicate)
                .allElementsBoundByIndex.first(where: { $0.isHittable })
        }
        func swipeGallery(_ direction: String) {
            let startX: CGFloat = direction == "left" ? 0.82 : 0.18
            let endX: CGFloat = direction == "left" ? 0.18 : 0.82
            let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.48))
            let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.48))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    
        let icon = springboard.descendants(matching: .icon)
            .matching(NSPredicate(format: "label == %@", "DUNE")).firstMatch
        for _ in 0..<4 where !icon.isHittable { springboard.swipeLeft() }
        guard icon.isHittable else { attachHierarchy("home-icon"); XCTFail("DUNE Home icon not reachable"); return }
        icon.press(forDuration: 1.2)
        guard let editHome = visible(["Edit Home Screen", "홈 화면 편집", "ホーム画面を編集"]) else {
            attachHierarchy("icon-context-menu")
            XCTFail("Edit Home Screen action unavailable")
            return
        }
        editHome.tap()
        if visible(["Add Widget", "Add Widgets", "위젯 추가", "ウィジェットを追加"]) == nil,
           let edit = visible(["Edit", "편집", "編集"]) { edit.tap() }
        guard let addWidget = visible(["Add Widget", "Add Widgets", "위젯 추가", "ウィジェットを追加"]) else {
            attachHierarchy("home-edit-mode")
            XCTFail("Add Widget control unavailable")
            return
        }
        addWidget.tap()
    
        // Search only the system gallery. DUNE Today is the StaticConfiguration
        // display name; DUNE is the app/category name. Do not select the separate
        // configurable Single Metric widget.
        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) && search.isHittable { search.tap(); search.typeText("DUNE") }
        if let category = springboard.cells.matching(NSPredicate(format: "label == %@", "DUNE"))
            .allElementsBoundByIndex.first(where: { $0.isHittable }) ?? visible(["DUNE"]) {
            category.tap()
        } else if let today = visible(["DUNE Today"]) {
            today.tap()
        } else {
            attachHierarchy("widget-gallery-search")
            XCTFail("DUNE widget gallery entry unavailable")
            return
        }
        guard visible(["DUNE Today"]) != nil ||
              springboard.descendants(matching: .any)["widget-small-root"].firstMatch.exists else {
            attachHierarchy("dune-gallery")
            XCTFail("DUNE Today gallery not identifiable; inspect system hierarchy")
            return
        }
    
        // Gallery uses the provider's standard placeholder, not user score data.
        // Home installation below uses the real production timeline.
        // WidgetKit may expose extension AX IDs in the gallery. Capture only a
        // visible family root, never a fabricated in-app preview or whole screen.
        for (family, direction) in [("small", "right"), ("medium", "left"), ("large", "left")] {
            let root = springboard.descendants(matching: .any)["widget-\(family)-root"].firstMatch
            for _ in 0..<3 where !root.isHittable { swipeGallery(direction) }
            guard root.isHittable else {
                attachHierarchy("gallery-\(family)-missing")
                XCTFail("WidgetKit \(family) preview root is not AX observable")
                return
            }
            let shot = XCTAttachment(screenshot: root.screenshot())
            shot.name = "DUNE Today system widget \(family) gallery"
            shot.lifetime = .keepAlways
            add(shot)
            attachHierarchy("gallery-\(family)")
        }
    
        // Return to Small and install one actual Home widget if the host permits it.
        let small = springboard.descendants(matching: .any)["widget-small-root"].firstMatch
        for _ in 0..<3 where !small.isHittable { swipeGallery("right") }
        guard small.isHittable else { attachHierarchy("return-to-small"); XCTFail("Small preview unavailable"); return }
        guard let addControl = visible(["Add Widget", "위젯 추가", "ウィジェットを追加"]) else {
            attachHierarchy("gallery-add-widget")
            XCTFail("System Add Widget action unavailable")
            return
        }
        addControl.tap()
        guard small.waitForExistence(timeout: 8) && small.isHittable else {
            attachHierarchy("home-widget-missing")
            XCTFail("Installed Small DUNE Today widget is not AX observable on Home")
            return
        }
        let homeShot = XCTAttachment(screenshot: small.screenshot())
        homeShot.name = "DUNE Today system widget small Home"
        homeShot.lifetime = .keepAlways
        add(homeShot)
        attachHierarchy("home-widget-small")
    }
}
