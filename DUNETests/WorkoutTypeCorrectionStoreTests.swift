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

    func testLocalizedTitlePreservesCustomMetadataExerciseName() {
        // Custom exercise name from HealthKit metadata (e.g. "Bench Press")
        // should be preserved, not replaced by activityType.displayName
        let workout = WorkoutSummary(
            id: "hk-custom-1",
            type: "Bench Press",
            activityType: .traditionalStrengthTraining,
            duration: 1800,
            calories: 220,
            distance: nil,
            date: Date()
        )

        let title = workout.localizedTitle(using: store)
        XCTAssertEqual(title, "Bench Press")
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

    func testGenericCorrectionsLocalizeWithoutRewritingStoredTitles() {
        for activity in WorkoutActivityType.allCases {
            let id = "generic-\(activity.rawValue)"
            store.setCorrectedTitle(activity.typeName, for: id)
            let workout = WorkoutSummary(
                id: id, type: activity.typeName, activityType: activity,
                duration: 900, calories: 100, distance: nil, date: Date()
            )
            XCTAssertEqual(workout.localizedTitle(using: store), activity.displayName)
            XCTAssertEqual(store.correctedTitle(for: id), activity.typeName)
            XCTAssertEqual(workout.type, activity.typeName)
            XCTAssertEqual(workout.activityType, activity)
        }
    }

    func testCustomCorrectionRemainsVerbatim() {
        store.setCorrectedTitle("My Running Intervals", for: "custom-running")
        let workout = WorkoutSummary(
            id: "custom-running", type: "Running", activityType: .running,
            duration: 900, calories: 100, distance: nil, date: Date()
        )
        XCTAssertEqual(workout.localizedTitle(using: store), "My Running Intervals")
        XCTAssertEqual(store.correctedTitle(for: "custom-running"), "My Running Intervals")
    }

    func testManualLegacyRawValuesKeepActivityClassification() {
        let library = ExerciseLibraryService(exercises: [])
        for activity in WorkoutActivityType.allCases {
            let record = ExerciseRecord(exerciseType: activity.rawValue, duration: 900)
            let item = ExerciseListItem.fromManualRecord(record, library: library)
            XCTAssertEqual(item.activityType, activity)
            XCTAssertEqual(item.displayName, activity.displayName)
            XCTAssertEqual(record.exerciseType, activity.rawValue)
            let namedItem = ExerciseListItem(
                id: record.id.uuidString, type: activity.typeName, localizedType: "Localized exercise",
                activityType: activity, duration: 900, calories: nil, distance: nil,
                date: record.date, source: .manual
            )
            XCTAssertNil(namedItem.secondaryDisplayName)
        }
        let custom = ExerciseListItem(
            id: "custom", type: "Bench Press", localizedType: "바벨 벤치프레스",
            activityType: .traditionalStrengthTraining, duration: 900,
            calories: nil, distance: nil, date: Date(), source: .manual
        )
        XCTAssertEqual(custom.secondaryDisplayName, "Bench Press")
    }
}
