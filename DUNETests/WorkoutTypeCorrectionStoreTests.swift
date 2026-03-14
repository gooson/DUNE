import XCTest
@testable import DUNE

final class WorkoutTypeCorrectionStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var store: WorkoutTypeCorrectionStore!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "WorkoutTypeCorrectionStoreTests")
        userDefaults.removePersistentDomain(forName: "WorkoutTypeCorrectionStoreTests")
        store = WorkoutTypeCorrectionStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "WorkoutTypeCorrectionStoreTests")
        userDefaults = nil
        store = nil
        super.tearDown()
    }

    func testSetAndGetCorrectedTitle() {
        store.setCorrectedTitle("체스트 프레스", for: "hk-1")

        XCTAssertEqual(store.correctedTitle(for: "hk-1"), "체스트 프레스")
    }

    func testSetCorrectedTitleTrimsWhitespace() {
        store.setCorrectedTitle("  Bench Press  ", for: "hk-2")

        XCTAssertEqual(store.correctedTitle(for: "hk-2"), "Bench Press")
    }

    func testSetCorrectedTitleRemovesWhenEmpty() {
        store.setCorrectedTitle("Bench Press", for: "hk-3")
        store.setCorrectedTitle("   ", for: "hk-3")

        XCTAssertNil(store.correctedTitle(for: "hk-3"))
    }

    func testSetCorrectedTitleRemovesWhenNil() {
        store.setCorrectedTitle("Bench Press", for: "hk-4")
        store.setCorrectedTitle(nil, for: "hk-4")

        XCTAssertNil(store.correctedTitle(for: "hk-4"))
    }

    func testBackfillTitlesStoresLinkedRecordTitle() {
        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "Incline Dumbbell Press",
            duration: 1800,
            healthKitWorkoutID: "hk-linked-1"
        )

        store.backfillTitles(from: [record])

        XCTAssertEqual(store.correctedTitle(for: "hk-linked-1"), "Incline Dumbbell Press")
    }

    func testBackfillTitlesDoesNotOverwriteExistingCorrection() {
        store.setCorrectedTitle("사용자 수정 제목", for: "hk-linked-2")
        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "Bench Press",
            duration: 1800,
            healthKitWorkoutID: "hk-linked-2"
        )

        store.backfillTitles(from: [record])

        XCTAssertEqual(store.correctedTitle(for: "hk-linked-2"), "사용자 수정 제목")
    }

    func testWorkoutSummaryLocalizedTitleUsesCorrectionStore() {
        store.setCorrectedTitle("레거시 벤치프레스", for: "hk-linked-3")
        let workout = WorkoutSummary(
            id: "hk-linked-3",
            type: "Strength",
            activityType: .traditionalStrengthTraining,
            duration: 1800,
            calories: 200,
            distance: nil,
            date: Date()
        )

        XCTAssertEqual(workout.localizedTitle(using: store), "레거시 벤치프레스")
    }

    func testLocalizedTitleFallsBackToActivityTypeDisplayName() {
        // "Tempo Run" doesn't match any typeName → should fall back to activityType.displayName
        let workout = WorkoutSummary(
            id: "hk-custom-1",
            type: "Tempo Run",
            activityType: .running,
            duration: 2880,
            calories: 612,
            distance: 10_200,
            date: Date()
        )

        let title = workout.localizedTitle(using: store)
        // Should NOT be "Tempo Run" (raw English)
        XCTAssertNotEqual(title, "Tempo Run")
        // Should be the localized displayName for .running
        XCTAssertEqual(title, WorkoutActivityType.running.displayName)
    }

    func testLocalizedTitleReturnsRawTypeForOtherActivity() {
        // activityType == .other with unrecognized title → should return raw type
        let workout = WorkoutSummary(
            id: "hk-custom-2",
            type: "My Custom Workout",
            activityType: .other,
            duration: 1800,
            calories: 100,
            distance: nil,
            date: Date()
        )

        XCTAssertEqual(workout.localizedTitle(using: store), "My Custom Workout")
    }
}
