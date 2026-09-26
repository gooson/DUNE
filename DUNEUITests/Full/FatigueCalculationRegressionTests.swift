@preconcurrency import XCTest

@MainActor
final class FatigueCalculationRegressionTests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .fatigueRegression }
    override var initialTabSelectionArgument: String? { "train" }
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testSixDayOldChestWorkoutsShowRecoveredCalculation() {
        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 30), "Activity data should finish loading")
        let chestID = "musclemap-body-front-chest"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(chestID, maxSwipes: 4), app.debugDescription)
        app.buttons[chestID].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["L1 / L10"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["6d ago"].exists)
        XCTAssertTrue(app.staticTexts["10 sets"].exists)
        addScreenshotAttachment(named: "chest-recovery-six-days")

        app.buttons["View Calculation"].tap()
        XCTAssertTrue(app.staticTexts["Fatigue Calculation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0.9"].exists, "6,200 kg volume should yield 0.9 rounded load")
        XCTAssertTrue(app.staticTexts["0.8"].exists, "5,600 kg volume should yield 0.8 load")
        XCTAssertTrue(app.staticTexts["0.02"].exists)
        XCTAssertTrue(app.staticTexts["Fully Recovered"].exists)
        XCTAssertFalse(app.staticTexts["Overtrained"].exists)
        addScreenshotAttachment(named: "chest-fatigue-corrected-calculation")
    }
}
