import Foundation
import Testing
@testable import DUNE

@Suite("LifeAutoAchievementService")
struct LifeAutoAchievementServiceTests {
    @Test("Weekly workout count targets count all entries")
    func weeklyWorkoutThresholds() {
        let referenceDate = day(2026, 3, 4, 12) // Wed
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(id: "hk-1", date: day(2026, 3, 2, 8)),
            makeEntry(id: "hk-2", date: day(2026, 3, 2, 18)),
            makeEntry(id: "hk-3", date: day(2026, 3, 3, 8)),
            makeEntry(id: "hk-4", date: day(2026, 3, 4, 8)),
            makeEntry(id: "hk-5", date: day(2026, 3, 5, 8))
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let weekly5 = progress(progresses, id: "weeklyWorkout5")
        let weekly7 = progress(progresses, id: "weeklyWorkout7")

        #expect(weekly5.currentValue == 5)
        #expect(weekly5.isCompleted == true)
        #expect(weekly7.currentValue == 5)
        #expect(weekly7.isCompleted == false)
        #expect(weekly5.title == String(localized: "Workout 5x / week"))
        #expect(weekly5.unit == String(localized: "workouts"))
        #expect(weekly5.progressText == String(localized: "\(Int(weekly5.currentValue))/\(Int(weekly5.targetValue)) workouts"))
    }

    @Test("Manual entries without HealthKit link are counted")
    func manualEntriesCountedWithoutHealthKit() {
        let referenceDate = day(2026, 3, 4, 12)
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(id: nil, date: day(2026, 3, 2, 8)),
            makeEntry(id: nil, date: day(2026, 3, 3, 9)),
            makeEntry(id: nil, date: day(2026, 3, 4, 10))
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let weekly5 = progress(progresses, id: "weeklyWorkout5")

        #expect(weekly5.currentValue == 3)
    }

    @Test("Week boundary follows Monday start")
    func mondayWeekBoundary() {
        let referenceDate = day(2026, 3, 2, 12) // Monday
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(id: "sun", date: day(2026, 3, 1, 10)), // Sunday (previous week)
            makeEntry(id: "mon", date: day(2026, 3, 2, 10))  // Monday (current week)
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let weekly5 = progress(progresses, id: "weeklyWorkout5")
        #expect(weekly5.currentValue == 1)
    }

    @Test("Running distance combines km and meter values")
    func runningDistanceNormalization() {
        let referenceDate = day(2026, 3, 4, 12)
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(id: "run-1", date: day(2026, 3, 2, 8), activityID: "running", distance: 5),      // km
            makeEntry(id: "run-2", date: day(2026, 3, 3, 8), activityID: "running", distance: 5_000),  // meter
            makeEntry(id: "run-3", date: day(2026, 3, 4, 8), activityID: "running", distance: 5)       // km
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let running = progress(progresses, id: "weeklyRunning15km")

        #expect(abs(running.currentValue - 15) < 0.001)
        #expect(running.isCompleted == true)
    }

    @Test("Strength and body-part goals are evaluated independently")
    func strengthAndBodyPartGoals() {
        let referenceDate = day(2026, 3, 4, 12)
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(
                id: "s1",
                date: day(2026, 3, 2, 7),
                hasSetData: true,
                primaryMuscles: [.chest]
            ),
            makeEntry(
                id: "s2",
                date: day(2026, 3, 3, 7),
                hasSetData: true,
                primaryMuscles: [.chest, .triceps]
            ),
            makeEntry(
                id: "s3",
                date: day(2026, 3, 4, 7),
                hasSetData: true,
                primaryMuscles: [.chest]
            )
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let strength3 = progress(progresses, id: "weeklyStrength3")
        let chest3 = progress(progresses, id: "weeklyChest3")
        let arms3 = progress(progresses, id: "weeklyArms3")

        #expect(strength3.currentValue == 3)
        #expect(strength3.isCompleted == true)
        #expect(chest3.currentValue == 3)
        #expect(chest3.isCompleted == true)
        #expect(arms3.currentValue == 1)
        #expect(arms3.isCompleted == false)
    }

    @Test("Retroactive streak counts consecutive achieved weeks")
    func retroactiveWeeklyStreak() {
        let referenceDate = day(2026, 3, 4, 12)
        let currentWeek = [
            makeEntry(id: "cw1", date: day(2026, 3, 2, 8)),
            makeEntry(id: "cw2", date: day(2026, 3, 2, 18)),
            makeEntry(id: "cw3", date: day(2026, 3, 3, 8)),
            makeEntry(id: "cw4", date: day(2026, 3, 4, 8)),
            makeEntry(id: "cw5", date: day(2026, 3, 5, 8))
        ]
        let previousWeek = [
            makeEntry(id: "pw1", date: day(2026, 2, 23, 8)),
            makeEntry(id: "pw2", date: day(2026, 2, 24, 8)),
            makeEntry(id: "pw3", date: day(2026, 2, 25, 8)),
            makeEntry(id: "pw4", date: day(2026, 2, 26, 8)),
            makeEntry(id: "pw5", date: day(2026, 2, 27, 8))
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(
            from: currentWeek + previousWeek,
            referenceDate: referenceDate
        )
        let weekly5 = progress(progresses, id: "weeklyWorkout5")
        #expect(weekly5.streakWeeks == 2)
    }

    @Test("Duplicate HealthKit workout IDs are counted once")
    func dedupByWorkoutID() {
        let referenceDate = day(2026, 3, 4, 12)
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(id: "dup", date: day(2026, 3, 2, 8)),
            makeEntry(id: "dup", date: day(2026, 3, 2, 8)),
            makeEntry(id: "unique", date: day(2026, 3, 3, 8))
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let weekly5 = progress(progresses, id: "weeklyWorkout5")
        #expect(weekly5.currentValue == 2)
    }

    @Test("Manual entries without sourceWorkoutID are deduped by timestamp and type")
    func dedupManualEntries() {
        let referenceDate = day(2026, 3, 4, 12)
        let entries: [LifeAutoWorkoutEntry] = [
            makeEntry(id: nil, date: day(2026, 3, 2, 8), activityID: "running"),
            makeEntry(id: nil, date: day(2026, 3, 2, 8), activityID: "running"), // same timestamp+type = dup
            makeEntry(id: nil, date: day(2026, 3, 2, 9), activityID: "running")  // different timestamp
        ]

        let progresses = LifeAutoAchievementService.calculateProgresses(from: entries, referenceDate: referenceDate)
        let weekly5 = progress(progresses, id: "weeklyWorkout5")
        #expect(weekly5.currentValue == 2)
    }

    // MARK: - Helpers

    private func progress(_ progresses: [LifeAutoAchievementProgress], id: String) -> LifeAutoAchievementProgress {
        guard let item = progresses.first(where: { $0.id == id }) else {
            Issue.record("Missing progress for rule: \(id)")
            return LifeAutoAchievementProgress(
                id: id,
                title: "",
                currentValue: 0,
                targetValue: 1,
                unit: "",
                isCompleted: false,
                streakWeeks: 0
            )
        }
        return item
    }

    private func makeEntry(
        id: String?,
        date: Date,
        activityID: String? = "running",
        exerciseType: String = "running",
        distance: Double? = nil,
        hasSetData: Bool = false,
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = []
    ) -> LifeAutoWorkoutEntry {
        LifeAutoWorkoutEntry(
            sourceWorkoutID: id,
            date: date,
            activityID: activityID,
            exerciseType: exerciseType,
            distance: distance,
            hasSetData: hasSetData,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles
        )
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: 0
        )) ?? Date()
    }
}
