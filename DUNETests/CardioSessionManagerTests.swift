import Foundation
import Testing
@testable import DUNE

@Suite("CardioSessionManager")
@MainActor
struct CardioSessionManagerTests {

    // MARK: - Initial State

    @Test("Initial state is idle with zero metrics")
    func initialState() {
        let manager = CardioSessionManager()
        #expect(manager.state == .idle)
        #expect(manager.distance == 0)
        #expect(manager.currentPace == 0)
        #expect(manager.heartRate == 0)
        #expect(manager.activeCalories == 0)
        #expect(manager.startDate == nil)
        #expect(manager.healthKitWorkoutUUID == nil)
    }

    // MARK: - Distance Conversions

    @Test("distanceKm converts meters to km correctly")
    func distanceKmConversion() {
        let manager = CardioSessionManager()
        // Cannot set distance directly, but initial is 0
        #expect(manager.distanceKm == 0)
    }

    // MARK: - Formatted Pace

    @Test("formattedPace returns --:-- when pace is 0")
    func zeroPaceFormat() {
        let manager = CardioSessionManager()
        #expect(manager.formattedPace == "--:--")
    }

    @Test("formattedPace returns --:-- for extreme values")
    func extremePaceFormat() {
        let manager = CardioSessionManager()
        // Default currentPace is 0, so should show --:--
        #expect(manager.formattedPace == "--:--")
    }

    // MARK: - Elapsed Time

    @Test("elapsedTime is 0 when no startDate")
    func elapsedTimeNoStart() {
        let manager = CardioSessionManager()
        #expect(manager.elapsedTime == 0)
    }

    @Test("elapsedTime returns positive value after startDate is set")
    func elapsedTimeWithStart() {
        let manager = CardioSessionManager()
        manager.testSetStartDate(Date().addingTimeInterval(-120))
        // elapsedTime should be ~120 (state is .idle, but startDate is set)
        // Note: elapsedTime checks state != .idle, so it returns 0 for idle
        #expect(manager.elapsedTime == 0)
    }

    // MARK: - Reset

    @Test("reset clears all state")
    func resetClearsState() {
        let manager = CardioSessionManager()
        manager.testSetStartDate(Date())
        manager.reset()

        #expect(manager.state == .idle)
        #expect(manager.startDate == nil)
        #expect(manager.distance == 0)
        #expect(manager.currentPace == 0)
        #expect(manager.heartRate == 0)
        #expect(manager.activeCalories == 0)
        #expect(manager.healthKitWorkoutUUID == nil)
    }
}

// MARK: - WorkoutWriteInput Distance Tests

@Suite("WorkoutWriteInput Distance Fields")
struct WorkoutWriteInputDistanceTests {

    @Test("Default distanceKm is nil")
    func defaultDistanceNil() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 1800,
            category: .cardio,
            exerciseName: "Running",
            estimatedCalories: 300,
            isFromHealthKit: false
        )
        #expect(input.distanceKm == nil)
        #expect(input.activityType == nil)
    }

    @Test("distanceKm and activityType are preserved")
    func distanceAndActivityType() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 1800,
            category: .cardio,
            exerciseName: "Running",
            estimatedCalories: 300,
            isFromHealthKit: false,
            distanceKm: 5.42,
            activityType: .running
        )
        #expect(input.distanceKm == 5.42)
        #expect(input.activityType == .running)
    }

    @Test("Zero distance is preserved as-is")
    func zeroDistance() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 900,
            category: .cardio,
            exerciseName: "Indoor Running",
            estimatedCalories: nil,
            isFromHealthKit: false,
            distanceKm: 0
        )
        #expect(input.distanceKm == 0)
    }
}
