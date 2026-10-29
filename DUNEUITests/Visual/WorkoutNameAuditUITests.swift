@preconcurrency import XCTest

@MainActor
final class WorkoutNameAuditUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-workout-name-audit", "--ui-test-style", "dark",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
    }

    func testGenericCorrectionsLocalizeAndMachineStairsRemainDistinct() {
        navigateToActivity()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 20))
        app.buttons[AXID.activityRecentSeeAll].firstMatch.tap()
        XCTAssertTrue(element(AXID.exerciseViewScreen).waitForExistence(timeout: 10))

        for (suffix, title) in [
            ("running", "달리기"), ("machine", "천국의 계단"),
            ("stairs", "계단 오르기"), ("custom", "My Bench Press")
        ] {
            let row = element("exercise-row-ui-name-audit-\(suffix)")
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            XCTAssertTrue(row.staticTexts[title].exists || row.label.contains(title),
                          "\(suffix) should display \(title), preserving custom names")
        }
        capture("Workout name audit Korean list")

        element("exercise-row-ui-name-audit-machine").tap()
        XCTAssertTrue(element("healthkit-workout-detail-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["천국의 계단"].firstMatch.exists)
        capture("Workout name audit machine detail")
        element("exercise-inspector-close").tap()
        XCTAssertTrue(element(AXID.exerciseViewScreen).exists)
        for (suffix, title) in [("stairs", "계단 오르기"), ("custom", "My Bench Press")] {
            element("exercise-row-ui-name-audit-\(suffix)").tap()
            XCTAssertTrue(element("healthkit-workout-detail-screen").waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts[title].firstMatch.exists)
            capture("Workout name audit \(suffix) detail")
            element("exercise-inspector-close").tap()
            XCTAssertTrue(element(AXID.exerciseViewScreen).exists)
        }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func testManualGenericCodeIsNotRepeatedBelowLocalizedName() {
        navigateToActivity()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 20))
        app.buttons[AXID.activityRecentSeeAll].firstMatch.tap()
        XCTAssertTrue(element(AXID.exerciseViewScreen).waitForExistence(timeout: 10))
        let row = element("exercise-row-barbell-bench-press")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.staticTexts["바벨 벤치프레스"].exists || row.label.contains("바벨 벤치프레스"))
        XCTAssertFalse(row.staticTexts["strength"].exists)
        XCTAssertFalse(row.label.contains("strength"))
        capture("Workout name audit generic manual list")
    }

    private func capture(_ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
