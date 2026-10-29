import Foundation
import Testing
@testable import DUNE

@Suite("Workout display names")
struct WorkoutDisplayNameTests {
    @Test("Every generic name and raw value uses the actual activity's display name",
          arguments: WorkoutActivityType.allCases)
    func allGenericNames(activity: WorkoutActivityType) {
        for title in [activity.typeName, activity.rawValue, "  \(activity.typeName.uppercased())\n"] {
            #expect(WorkoutActivityType.localizedDisplayName(
                forStoredTitle: title, preferredActivity: activity
            ) == activity.displayName)
        }
    }

    @Test("Custom names are never generalized by keyword inference", arguments: [
        "Bench Press", "My Custom Workout", "Tempo Run", "Running Recovery",
        "Stair Climber Intervals", "천국의 계단 인터벌", "민수의 달리기"
    ])
    func customNames(title: String) {
        #expect(WorkoutActivityType.localizedDisplayName(
            forStoredTitle: title, preferredActivity: .running
        ) == nil)
    }

    @Test("Shared historical labels honor the HealthKit activity subtype")
    func sharedHistoricalNames() {
        for activity in [WorkoutActivityType.functionalStrengthTraining, .cardioDance] {
            #expect(WorkoutActivityType.localizedDisplayName(
                forStoredTitle: activity.typeName, preferredActivity: activity
            ) == activity.displayName)
        }
    }

    @Test("Machine and actual stair labels remain separate without changing stored names")
    func stairNameContracts() {
        #expect(WorkoutActivityType.stairClimbing.rawValue == "stairClimbing")
        #expect(WorkoutActivityType.stairStepper.rawValue == "stairStepper")
        #expect(WorkoutActivityType.stairClimbing.typeName == "Stair Climbing")
        #expect(WorkoutActivityType.stairStepper.typeName == "Stair Stepper")
        #expect(WorkoutActivityType.localizedDisplayName(forStoredTitle: "Stair Climber")
                == WorkoutActivityType.stairClimbing.displayName)
        #expect(WorkoutActivityType.localizedDisplayName(forStoredTitle: "Stairs")
                == WorkoutActivityType.stairStepper.displayName)
        #expect(WorkoutActivityType.localizedDisplayName(
            forStoredTitle: "계단 오르기", preferredActivity: .stairClimbing
        ) == WorkoutActivityType.stairClimbing.displayName)
        #expect(WorkoutActivityType.localizedDisplayName(
            forStoredTitle: "계단 오르기", preferredActivity: .stairStepper
        ) == nil)
    }

    @Test("Blank and unknown generic titles have no localization match")
    func unknownNames() {
        #expect(WorkoutActivityType.localizedDisplayName(forStoredTitle: " \n") == nil)
        #expect(WorkoutActivityType.localizedDisplayName(forStoredTitle: "Unknown Activity") == nil)
    }
}
