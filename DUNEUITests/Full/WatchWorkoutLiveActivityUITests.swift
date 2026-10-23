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
    override var shouldSeedMockData: Bool { true }
    override var additionalLaunchArguments: [String] {
        [
            "--ui-test-theme", "desertWarm", "--ui-test-style", "light",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
    }

    func testSystemDUNETodayWidgetFamilies() throws {
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
            let predicate = NSPredicate(format: "label IN %@", labels + labels.map { " " + $0 })
            let element = springboard.descendants(matching: .any).matching(predicate).firstMatch
            return element.exists && element.isHittable ? element : nil
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
        let category = springboard.cells.matching(NSPredicate(format: "label == %@", "DUNE")).firstMatch
        if category.exists && category.isHittable {
            category.tap()
        } else if let today = visible(["DUNE Today", "오늘의 DUNE", "今日のDUNE"]) {
            today.tap()
        } else {
            attachHierarchy("widget-gallery-search")
            XCTFail("DUNE widget gallery entry unavailable")
            return
        }
        guard visible(["DUNE Today", "오늘의 DUNE", "今日のDUNE"]) != nil ||
              springboard.descendants(matching: .any)["widget-small-root"].firstMatch.exists else {
            attachHierarchy("dune-gallery")
            XCTFail("DUNE Today gallery not identifiable; inspect system hierarchy")
            return
        }

        // SpringBoard exposes the real widget as a native host button. WidgetKit
        // does not expose the extension's internal IDs in this OS gallery.
        let titles = ["DUNE Today", "오늘의 DUNE", "今日のDUNE"]
        let sizes = ["small": ["Small", "작게", "小"],
                     "medium": ["Medium", "중간", "中"],
                     "large": ["Large", "크게", "大"]]
        func widget(_ family: String, onHome: Bool = false) -> XCUIElement? {
            let title = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@",
                                    titles[0], titles[1], titles[2])
            let values = sizes[family] ?? []
            let size = NSPredicate(format: "value CONTAINS[c] %@ OR value CONTAINS[c] %@ OR value CONTAINS[c] %@",
                                   values[0], values[1], values[2])
            let query = springboard.descendants(matching: .any)
                .matching(NSCompoundPredicate(andPredicateWithSubpredicates: [title, size])).firstMatch
            if query.exists && query.isHittable { return query }
            if onHome {
                let home = springboard.descendants(matching: .any).matching(title).firstMatch
                if home.exists && home.isHittable && home.frame.width > 140 && home.frame.height > 140 {
                    return home
                }
            }
            return nil
        }
        // Gallery snapshots use the provider's standard placeholder. The Home
        // installation uses the production timeline written by the seeded app.
        for family in ["small", "medium", "large"] {
            for _ in 0..<3 where widget(family) == nil { swipeGallery("left") }
            let root = try XCTUnwrap(widget(family), "The native \(family) widget host should be visible")
            XCTAssertTrue(springboard.windows.firstMatch.frame.contains(root.frame),
                          "The entire \(family) widget must fit in the gallery viewport")
            if family == "small" { XCTAssertEqual(root.frame.width, root.frame.height, accuracy: 5) }
            if family == "medium" { XCTAssertGreaterThan(root.frame.width, root.frame.height * 1.5) }
            if family == "large" { XCTAssertGreaterThan(root.frame.height, 250) }
            let shot = XCTAttachment(screenshot: root.screenshot())
            shot.name = "DUNE Today system widget \(family) gallery"
            shot.lifetime = .keepAlways
            add(shot)
            attachHierarchy("gallery-\(family)")
        }

        // The gallery renders all three real extension families above. Home
        // placement uses a different SpringBoard AX contract and is tracked as
        // unverified rather than expanding this family-layout regression.
        XCUIDevice.shared.press(.home)
    }
}
