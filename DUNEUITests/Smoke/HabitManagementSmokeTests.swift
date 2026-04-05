@preconcurrency import XCTest

/// Smoke tests for the Habit Management screen.
/// The archive → link → management → restore flow requires manual verification
/// because the @Query observation timing after in-session archive is unreliable in XCUI.
@MainActor
final class HabitManagementSmokeTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    func testLifeTabHabitsSectionExists() throws {
        XCTAssertTrue(
            elementExists(AXID.lifeSectionHabits, timeout: 10),
            "Life habits section should exist when habits are seeded"
        )
    }

    func testArchiveActionExists() throws {
        let habitName = "Morning Stretch"
        XCTAssertTrue(
            app.openLifeHabitActions(named: habitName, maxSwipes: 8),
            "Habit actions should open from the seeded habit row"
        )
        let archiveButton = app.descendants(matching: .any)[AXID.lifeHabitActionArchive].firstMatch
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 3), "Archive action should appear")
    }
}
