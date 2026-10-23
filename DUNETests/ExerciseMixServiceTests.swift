import Foundation
import Testing
@testable import DUNE

@Suite("Exercise Mix composition")
struct ExerciseMixServiceTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_787_800_000)

    private func entry(
        _ id: String, daysAgo: Int = 0, name: String = "Bench Press",
        kind: ExerciseMixKind = .strength, muscles: [MuscleGroup] = [.chest],
        sets: Int = 0, linked: String? = nil, healthKit: Bool = false,
        minutes: Double? = nil, kilometers: Double? = nil
    ) -> ExerciseMixEntry {
        ExerciseMixEntry(id: id, linkedWorkoutID: linked, isHealthKit: healthKit,
                         date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
                         name: name, kind: kind, primaryMuscles: muscles,
                         completedSets: sets, durationMinutes: minutes, distanceKm: kilometers)
    }

    @Test("Empty and cutoff have no fabricated proportions")
    func emptyAndCutoff() {
        let empty = ExerciseMixService.analyze([], asOf: now, calendar: calendar)
        #expect(empty.total == 0)
        #expect(empty.muscles.isEmpty)
        #expect(empty.frequencies.isEmpty)
        let older = ExerciseMixService.analyze([entry("old", daysAgo: 28)], asOf: now, calendar: calendar)
        #expect(older.total == 0)
    }

    @Test("Primary muscles split completed sets once, unknown sets are excluded")
    func fractionalMuscles() {
        let result = ExerciseMixService.analyze([
            entry("compound", muscles: [.chest, .triceps], sets: 3),
            entry("unknown", muscles: [], sets: 2),
            entry("run", name: "Running", kind: .cardio, muscles: [.quadriceps], sets: 0)
        ], asOf: now, calendar: calendar)
        #expect(result.total == 3)
        #expect(result.strength == 2)
        #expect(result.cardio == 1)
        #expect(result.unattributedSets == 2)
        #expect(result.muscles.count == 2)
        #expect(result.muscles.allSatisfy { $0.sets == 1.5 && $0.fraction == 0.5 })
        #expect(result.muscles.map(\.sets).reduce(0, +) == 3)
    }

    @Test("Linked and orphan app workouts deduplicate while third-party cardio remains")
    func mergedSources() {
        let result = ExerciseMixService.analyze([
            entry("manual-1", linked: "hk-1", sets: 2),
            entry("manual-2", name: "Squat", sets: 2),
            entry("hk-1", linked: "hk-1", healthKit: true),
            entry("hk-2", name: "Squat", linked: "hk-2", healthKit: true),
            entry("third-party", name: "Running", kind: .cardio, healthKit: true,
                  minutes: 42, kilometers: 7)
        ], asOf: now, calendar: calendar)
        #expect(result.total == 3)
        #expect(result.strength == 2)
        #expect(result.cardio == 1)
        #expect(result.frequencies.reduce(0) { $0 + $1.count } == result.total)
        #expect(result.cardioTypes.first?.durationMinutes == 42)
        #expect(result.cardioTypes.first?.distanceKm == 7)
        #expect(result.weeks.reduce(0) { $0 + $1.total } == result.total)
    }

    @Test("Manual links outside the period cannot hide a current HealthKit workout")
    func outOfPeriodLink() {
        let result = ExerciseMixService.analyze([
            entry("old-manual", daysAgo: 28, linked: "hk-current"),
            entry("future-manual", daysAgo: -1, linked: "hk-second"),
            entry("hk-current", linked: "hk-current", healthKit: true),
            entry("hk-second", linked: "hk-second", healthKit: true)
        ], asOf: now, calendar: calendar)

        #expect(result.total == 2)
        #expect(result.strength == 2)
    }

    @Test("App workout proximity compares stored names before localization")
    func rawNameProximity() {
        var manual = entry("manual", name: "Localized Squat")
        manual.dedupName = "Squat"
        var workout = entry("hk", name: "Squat", linked: "hk", healthKit: true)
        workout.dedupName = "Squat"

        let result = ExerciseMixService.analyze([manual, workout], asOf: now, calendar: calendar)

        #expect(result.total == 1)
        #expect(result.frequencies.first?.exerciseName == "Localized Squat")
    }
}
