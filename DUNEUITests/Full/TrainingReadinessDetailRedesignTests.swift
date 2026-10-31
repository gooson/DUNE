@preconcurrency import XCTest

/// Neutral normal-text capture that runs on both the original and redesigned A02 view.
@MainActor
final class TrainingReadinessDetailRedesignTests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "--ui-test-style", "light", "--ui-disable-animations",
            "-morningBriefingDisabled", "YES"
        ]
    }

    func testSeededReadinessNormalScreenAndCapture() {
        navigateToActivity()
        let readinessHero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(readinessHero.waitForExistence(timeout: 15), "Seeded Activity readiness entry should exist")
        XCTAssertTrue(readinessHero.isHittable, "Activity readiness entry should be tappable")
        readinessHero.auditTap()

        let detail = app.scrollViews[AXID.activityTrainingReadinessDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Training Readiness detail should open")
        let navigation = app.navigationBars["Training Readiness"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 5), "Original Training Readiness title should remain")

        // Capture the untouched top viewport before probing lower sections or scrolling.
        addScreenshotAttachment(named: "A02 seeded normal text detail top")
        VisualAudit.capture("A02 seeded normal text detail top")

        let periods = app.segmentedControls[AXID.trainingReadinessPeriodPicker].firstMatch
        XCTAssertTrue(periods.waitForExistence(timeout: 10), "The existing five-period control should remain")
        for label in ["D", "W", "M", "6M", "Y"] {
            XCTAssertTrue(periods.buttons[label].exists, "The original \(label) period should remain")
        }
        let composition = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(composition.waitForExistence(timeout: 10), "The original score composition should remain")
        for (title, weight) in [
            ("HRV Variability", "30%"),
            ("Sleep Quality", "25%"),
            ("Resting Heart Rate", "20%"),
            ("Recovery Status", "15%"),
            ("Trend Bonus", "10%")
        ] {
            let row = composition.descendants(matching: .staticText).matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, weight)
            ).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Original \(title) \(weight) contribution should remain")
        }

        let back = navigation.buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable, "Native Back should be usable")
        back.auditTap()
        XCTAssertTrue(readinessHero.waitForExistence(timeout: 8), "Back should return to Activity")
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5), "Detail should close after native Back")
    }
}
