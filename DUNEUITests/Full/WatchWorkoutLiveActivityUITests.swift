@preconcurrency import XCTest

@MainActor
final class WatchWorkoutLiveActivityUITests: UITestBaseCase {
    // These tests inspect SpringBoard, so the app-navigation setup in the base
    // class is deliberately skipped. The base teardown still ends the app.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunningNotificationCenterPresentation() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "running"
        )
    }

    func testCyclingNotificationCenterPresentation() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "cycling",
            exerciseName: "Outdoor Cycle", evidenceName: "cycling"
        )
    }

    func testPausedNotificationCenterPresentation() {
        captureNotificationCenter(
            phase: "paused", expectedStatuses: ["Paused", "일시 정지", "一時停止"],
            activityType: "running"
        )
    }

    func testStaleNotificationCenterHidesOutdatedMetrics() {
        captureNotificationCenter(
            phase: "stale", expectedStatuses: ["Waiting for Watch", "Watch 연결 대기", "Watchとの接続待ち"],
            activityType: "running"
        )
    }

    func testLongStrengthNameNotificationCenterPresentation() {
        captureNotificationCenter(
            phase: "running",
            expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "traditionalStrengthTraining",
            exerciseName: "체스트 프레스 머신 · 플레이트 로드",
            evidenceName: "strength-long-name"
        )
    }

    func testGoldCardioDistancePresentation() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "running", evidenceName: "gold-cardio-distance",
            metric: "distance", style: "goldImpact", theme: "evergreen", expectedPrimaryFragments: ["1.2", "km"]
        )
    }

    func testZeroDistanceIsPresentedAsARealValue() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "running", evidenceName: "gold-cardio-zero-distance",
            metric: "distance", style: "goldImpact",
            fixtureArguments: ["--ui-watch-live-activity-zero-distance"],
            expectedPrimaryFragments: ["0"]
        )
    }

    func testUnsupportedDistanceFallsBackToElapsedTime() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "running", evidenceName: "gold-cardio-no-distance",
            metric: "distance", style: "goldImpact",
            fixtureArguments: ["--ui-watch-live-activity-no-distance"],
            expectedPrimaryFragments: [":"], absentMetricIdentifier: "watch-workout-distance"
        )
    }

    func testGoldStrengthCurrentWeightPresentation() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "traditionalStrengthTraining", exerciseName: "Strength Training",
            evidenceName: "gold-strength-weight", metric: "weight", style: "goldImpact",
            expectedPrimaryFragments: ["60", "kg"], expectsWeight: true
        )
    }

    func testMissingCurrentWeightFallsBackToElapsedTime() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "traditionalStrengthTraining", exerciseName: "Strength Training",
            evidenceName: "gold-strength-no-weight", metric: "weight", style: "goldImpact",
            fixtureArguments: ["--ui-watch-live-activity-missing-weight"],
            expectedPrimaryFragments: [":"], expectsWeight: false
        )
    }

    func testZeroCurrentWeightIsPresentedAsARealValue() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "traditionalStrengthTraining", exerciseName: "Strength Training",
            evidenceName: "gold-strength-zero-weight", metric: "weight", style: "goldImpact",
            fixtureArguments: ["--ui-watch-live-activity-zero-weight"],
            expectedPrimaryFragments: ["0", "kg"], expectsWeight: true
        )
    }

    func testStandardHeartRatePresentation() {
        captureNotificationCenter(
            phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"],
            activityType: "running", evidenceName: "standard-heart-rate",
            metric: "heartRate", style: "standard", expectedPrimaryFragments: ["142", "bpm"]
        )
    }

    func testPausedGoldStrengthKeepsSelectedWeight() {
        captureNotificationCenter(
            phase: "paused", expectedStatuses: ["Paused", "일시 정지", "一時停止"],
            activityType: "traditionalStrengthTraining", exerciseName: "Strength Training",
            evidenceName: "paused-gold-strength-weight", metric: "weight", style: "goldImpact",
            expectedPrimaryFragments: ["60", "kg"], expectsWeight: true
        )
    }

    func testStaleGoldDistanceHidesSelectedAndSecondaryMetrics() {
        captureNotificationCenter(
            phase: "stale", expectedStatuses: ["Waiting for Watch", "Watch 연결 대기", "Watchとの接続待ち"],
            activityType: "running", evidenceName: "stale-gold-cardio-distance",
            metric: "distance", style: "goldImpact"
        )
    }

    private func captureNotificationCenter(
        phase: String,
        expectedStatuses: [String],
        activityType: String,
        exerciseName: String = "Outdoor Run",
        evidenceName: String? = nil,
        metric: String = "elapsedTime",
        style: String = "goldImpact",
        theme: String = "desertWarm",
        fixtureArguments: [String] = [],
        expectedPrimaryFragments: [String] = [],
        expectsWeight: Bool? = nil,
        absentMetricIdentifier: String? = nil
    ) {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-watch-live-activity", phase,
            "--ui-watch-live-activity-name", exerciseName,
            "--ui-watch-live-activity-type", activityType,
            "--ui-watch-live-activity-metric", metric,
            "--ui-watch-live-activity-style", style,
            "--ui-test-theme", theme,
            "--ui-test-style", "dark",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        configuration.additionalArguments += fixtureArguments
        launchApp(with: configuration)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Pull from the left side of the status bar, away from Dynamic Island.
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.01))
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.72))
        top.press(forDuration: 0.05, thenDragTo: bottom)

        let title = springboard.staticTexts["watch-workout-title"].firstMatch
        let didFindTitle = title.waitForExistence(timeout: 15)
        // Extensions use SpringBoard's language, independent of the app launch locale.
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "허용", "許可"])).firstMatch
        if allow.waitForExistence(timeout: 2) { allow.tap() }

        let root = springboard.descendants(matching: .any)["watch-workout-activity"].firstMatch
        let activity: XCUIElement? = root.waitForExistence(timeout: 5) ? root : nil
        if phase == "stale", let activity {
            let waiting = activity.descendants(matching: .any)
                .matching(NSPredicate(format: "label IN %@", expectedStatuses)).firstMatch
            XCTAssertTrue(waiting.waitForExistence(timeout: 12), "The system should transition to its stale presentation")
        }
        let hierarchy = springboard.debugDescription
        attachEvidence(phase: evidenceName ?? phase, hierarchy: hierarchy, activity: activity)

        XCTAssertTrue(didFindTitle, "SpringBoard should display the seeded workout")
        XCTAssertTrue(hierarchy.contains(exerciseName), "Workout title should appear in system UI")
        XCTAssertTrue(expectedStatuses.contains(where: hierarchy.contains), "Localized workout status should appear in system UI")
        if let activity {
            XCTAssertTrue(springboard.windows.firstMatch.frame.contains(activity.frame),
                          "The complete Live Activity must fit in the system viewport")
            // The header icon is decorative for VoiceOver. Verify its glyph visually
            // in the attachment; snapshot unit tests cover symbol selection.
            let brand = activity.staticTexts["watch-workout-brand"].firstMatch
            XCTAssertTrue(brand.exists, "The Live Activity should identify DUNE")
            if brand.exists {
                XCTAssertEqual(brand.label, "DUNE")
                XCTAssertTrue(activity.frame.contains(brand.frame), "The DUNE wordmark must fit inside the activity")
            }
            let activityHierarchy = activity.debugDescription
            if phase == "stale" {
                for identifier in ["watch-workout-primary-metric", "watch-workout-weight", "watch-workout-elapsed", "watch-workout-heart-rate", "watch-workout-calories", "watch-workout-distance"] {
                    XCTAssertFalse(activity.descendants(matching: .any)[identifier].firstMatch.exists,
                                   "Outdated \(identifier) must be hidden")
                }
            } else {
                XCTAssertTrue(activityHierarchy.contains("142"), "Heart rate should appear in system UI")
                XCTAssertTrue(activityHierarchy.contains("86"), "Active calories should appear in system UI")
                for identifier in ["watch-workout-elapsed", "watch-workout-heart-rate", "watch-workout-calories"] {
                    let element = activity.descendants(matching: .any)[identifier].firstMatch
                    XCTAssertTrue(element.exists, "The system should expose \(identifier)")
                    if element.exists {
                        XCTAssertTrue(activity.frame.contains(element.frame), "\(identifier) must fit inside the activity")
                    }
                }
                let primary = activity.descendants(matching: .any)["watch-workout-primary-metric"].firstMatch
                XCTAssertTrue(primary.exists, "The system should expose the selected primary metric")
                if primary.exists {
                    XCTAssertTrue(activity.frame.contains(primary.frame), "The selected metric must fit inside the activity")
                    let accessibleText = primary.debugDescription
                    for fragment in expectedPrimaryFragments {
                        XCTAssertTrue(accessibleText.contains(fragment), "Primary metric should expose \(fragment): \(accessibleText)")
                    }
                }
                if let expectsWeight {
                    let weight = activity.descendants(matching: .any)["watch-workout-weight"].firstMatch
                    XCTAssertEqual(weight.exists, expectsWeight, "Only a current set weight should be exposed")
                }
                if let absentMetricIdentifier {
                    XCTAssertFalse(activity.descendants(matching: .any)[absentMetricIdentifier].firstMatch.exists,
                                   "Unavailable metric \(absentMetricIdentifier) must be hidden")
                }
            }
        }
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
        func widget(_ family: String) -> XCUIElement? {
            let title = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@",
                                    titles[0], titles[1], titles[2])
            let values = sizes[family] ?? []
            let size = NSPredicate(format: "value CONTAINS[c] %@ OR value CONTAINS[c] %@ OR value CONTAINS[c] %@",
                                   values[0], values[1], values[2])
            let query = springboard.descendants(matching: .any)
                .matching(NSCompoundPredicate(andPredicateWithSubpredicates: [title, size])).firstMatch
            if query.exists && query.isHittable { return query }
            return nil
        }
        // Gallery snapshots render the production provider's standard placeholder.
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
