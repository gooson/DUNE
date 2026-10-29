import Foundation
import Testing
@testable import DUNE

@Suite("Cardio Atlas source identity")
@MainActor
struct CardioAtlasHistoryTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("A different known local link never consumes a simultaneous Watch history entry")
    func differentKnownIdentity() {
        let record = ExerciseRecord(date: date, exerciseType: "running", duration: 600, distance: 2)
        record.healthKitWorkoutID = "HK-outside-history-page"
        let watch = workout(id: "HK-simultaneous-watch", fromApp: true)
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [watch], current: session(id: record.id.uuidString))
        #expect(result.count == 2)
        #expect(result.contains { $0.id == watch.id })
    }

    @Test("Local kilometers convert to meters and linked HealthKit samples count once")
    func linkedSources() throws {
        let record = ExerciseRecord(date: date, exerciseType: "running", duration: 600, distance: 2)
        record.healthKitWorkoutID = "atlas-history-linked"
        let current = session(id: record.id.uuidString)
        let imported = workout(id: "atlas-history-linked", fromApp: true)
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [imported], current: current)
        #expect(result.count == 1)
        #expect(result.first?.distanceMeters == 2_000)
    }

    @Test("An imported detail replaces its local alias and keeps unrelated Watch workouts")
    func importedDetailAlias() {
        let record = ExerciseRecord(date: date, exerciseType: "running", duration: 600, distance: 2)
        record.healthKitWorkoutID = "atlas-history-current"
        let current = session(id: "atlas-history-current")
        let watch = WorkoutSummary(
            id: "atlas-history-watch", type: "Running", activityType: .running,
            duration: 1_200, calories: nil, distance: 3_000,
            date: date.addingTimeInterval(-3_600), isFromThisApp: true
        )
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [watch], current: current)
        #expect(Set(result.map(\.id)) == [current.id, watch.id])
    }

    @Test("Floors remain duration progress and broad cardio categories are supported")
    func nonDistanceAndCategories() {
        let record = ExerciseRecord(date: date, exerciseType: "stairClimbing", duration: 900)
        record.floorsAscended = 30
        let current = CardioAtlasSession(
            id: "another-stair-session", activityType: .stairClimbing,
            date: date.addingTimeInterval(1_000), duration: 600, distanceMeters: nil
        )
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [], current: current)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.distanceMeters == nil })
        #expect(WorkoutActivityType.swimming.isAtlasSupported)
        #expect(WorkoutActivityType.elliptical.isAtlasSupported)
        #expect(WorkoutActivityType.cardioDance.isAtlasSupported)
        #expect(WorkoutActivityType.swimBikeRun.isAtlasSupported)
        #expect(!WorkoutActivityType.traditionalStrengthTraining.isAtlasSupported)
    }

    private func session(id: String) -> CardioAtlasSession {
        CardioAtlasSession(id: id, activityType: .running, date: date, duration: 600, distanceMeters: 2_000)
    }

    private func workout(id: String, fromApp: Bool) -> WorkoutSummary {
        WorkoutSummary(id: id, type: "Running", activityType: .running, duration: 600,
                       calories: nil, distance: 2_000, date: date, isFromThisApp: fromApp)
    }
}
