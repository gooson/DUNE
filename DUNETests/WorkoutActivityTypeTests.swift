import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutActivityType")
struct WorkoutActivityTypeTests {

    @Test("Running is distance-based")
    func runningIsDistanceBased() {
        #expect(WorkoutActivityType.running.isDistanceBased)
    }

    @Test("Strength training is not distance-based")
    func strengthNotDistanceBased() {
        #expect(!WorkoutActivityType.traditionalStrengthTraining.isDistanceBased)
    }

    @Test("Category mapping — running is cardio")
    func runningIsCardio() {
        #expect(WorkoutActivityType.running.category == .cardio)
    }

    @Test("Category mapping — yoga is mindBody")
    func yogaIsMindBody() {
        #expect(WorkoutActivityType.yoga.category == .mindBody)
    }

    @Test("Category mapping — boxing is combat")
    func boxingIsCombat() {
        #expect(WorkoutActivityType.boxing.category == .combat)
    }

    @Test("typeName returns readable name")
    func typeNameReadable() {
        #expect(WorkoutActivityType.running.typeName == "Running")
        #expect(WorkoutActivityType.highIntensityIntervalTraining.typeName == "HIIT")
        #expect(WorkoutActivityType.other.typeName == "Workout")
    }

    @Test("All cases have non-empty typeName")
    func allTypesHaveNames() {
        for type in WorkoutActivityType.allCases {
            #expect(!type.typeName.isEmpty, "Missing typeName for \(type.rawValue)")
        }
    }
}

// MARK: - infer(from:) Tests

@Suite("WorkoutActivityType.infer")
struct WorkoutActivityTypeInferTests {

    @Test("Matches full keyword — Running")
    func matchRunning() {
        #expect(WorkoutActivityType.infer(from: "Running") == .running)
        #expect(WorkoutActivityType.infer(from: "Outdoor Running") == .running)
    }

    @Test("Matches full keyword — Walking")
    func matchWalking() {
        #expect(WorkoutActivityType.infer(from: "Walking") == .walking)
        #expect(WorkoutActivityType.infer(from: "Power Walking") == .walking)
    }

    @Test("Matches cycling keywords")
    func matchCycling() {
        #expect(WorkoutActivityType.infer(from: "Indoor Cycling") == .cycling)
        #expect(WorkoutActivityType.infer(from: "Stationary Bike") == .cycling)
        #expect(WorkoutActivityType.infer(from: "Spin Cycle") == .cycling)
    }

    @Test("Matches swimming keywords")
    func matchSwimming() {
        #expect(WorkoutActivityType.infer(from: "Swimming") == .swimming)
        #expect(WorkoutActivityType.infer(from: "Open Water Swim") == .swimming)
    }

    @Test("Matches hiking keywords")
    func matchHiking() {
        #expect(WorkoutActivityType.infer(from: "Hiking") == .hiking)
        #expect(WorkoutActivityType.infer(from: "Mountain Hike") == .hiking)
    }

    @Test("Matches mind-body keywords")
    func matchMindBody() {
        #expect(WorkoutActivityType.infer(from: "Yoga Flow") == .yoga)
        #expect(WorkoutActivityType.infer(from: "Pilates Mat") == .pilates)
    }

    @Test("Matches rowing — full word only")
    func matchRowing() {
        #expect(WorkoutActivityType.infer(from: "Rowing Machine") == .rowing)
    }

    @Test("Matches combat keywords")
    func matchCombat() {
        #expect(WorkoutActivityType.infer(from: "Boxing Bag Work") == .boxing)
        #expect(WorkoutActivityType.infer(from: "Kickboxing Class") == .kickboxing)
    }

    @Test("Matches climbing")
    func matchClimbing() {
        #expect(WorkoutActivityType.infer(from: "Rock Climbing") == .climbing)
    }

    @Test("Matches jump rope")
    func matchJumpRope() {
        #expect(WorkoutActivityType.infer(from: "Jump Rope HIIT") == .jumpRope)
        #expect(WorkoutActivityType.infer(from: "Jumprope Workout") == .jumpRope)
    }

    @Test("Matches dance keywords")
    func matchDance() {
        #expect(WorkoutActivityType.infer(from: "Zumba Dancing") == .socialDance)
        #expect(WorkoutActivityType.infer(from: "Dance Cardio") == .socialDance)
    }

    @Test("Matches core training")
    func matchCore() {
        #expect(WorkoutActivityType.infer(from: "Core Workout") == .coreTraining)
    }

    @Test("Case insensitive")
    func caseInsensitive() {
        #expect(WorkoutActivityType.infer(from: "SWIMMING") == .swimming)
        #expect(WorkoutActivityType.infer(from: "yOgA") == .yoga)
    }

    @Test("Returns nil for unmatched exercise names")
    func noMatch() {
        #expect(WorkoutActivityType.infer(from: "Bench Press") == nil)
        #expect(WorkoutActivityType.infer(from: "Plank") == nil)
        #expect(WorkoutActivityType.infer(from: "Deadlift") == nil)
        #expect(WorkoutActivityType.infer(from: "Lat Pulldown") == nil)
    }

    @Test("No false-positive: 'Dumbbell Row' should NOT match rowing (only 'rowing' keyword)")
    func noFalsePositiveRow() {
        // "Dumbbell Row" does not contain "rowing", so it should NOT match
        #expect(WorkoutActivityType.infer(from: "Dumbbell Row") == nil)
        #expect(WorkoutActivityType.infer(from: "Barbell Row") == nil)
        #expect(WorkoutActivityType.infer(from: "Seated Cable Row") == nil)
    }

    @Test("Empty string returns nil")
    func emptyString() {
        #expect(WorkoutActivityType.infer(from: "") == nil)
    }
}

// MARK: - ExerciseCategory.defaultActivityType Tests

@Suite("ExerciseCategory.defaultActivityType")
struct ExerciseCategoryDefaultActivityTypeTests {

    @Test("Strength maps to traditionalStrengthTraining")
    func strength() {
        #expect(ExerciseCategory.strength.defaultActivityType == .traditionalStrengthTraining)
    }

    @Test("Cardio maps to mixedCardio")
    func cardio() {
        #expect(ExerciseCategory.cardio.defaultActivityType == .mixedCardio)
    }

    @Test("HIIT maps to highIntensityIntervalTraining")
    func hiit() {
        #expect(ExerciseCategory.hiit.defaultActivityType == .highIntensityIntervalTraining)
    }

    @Test("Flexibility maps to flexibility")
    func flexibility() {
        #expect(ExerciseCategory.flexibility.defaultActivityType == .flexibility)
    }

    @Test("Bodyweight maps to functionalStrengthTraining")
    func bodyweight() {
        #expect(ExerciseCategory.bodyweight.defaultActivityType == .functionalStrengthTraining)
    }
}

@Suite("MilestoneDistance")
struct MilestoneDistanceTests {

    @Test("Detects 5K from distance >= 5000m")
    func detect5K() {
        // detect returns highest matching milestone where distance >= meters
        #expect(MilestoneDistance.detect(from: 5000) == .fiveK)
        #expect(MilestoneDistance.detect(from: 5150) == .fiveK)
        // Below 5000 → nil
        #expect(MilestoneDistance.detect(from: 4850) == nil)
    }

    @Test("Detects 10K from distance >= 10000m")
    func detect10K() {
        #expect(MilestoneDistance.detect(from: 10000) == .tenK)
        // 7500 >= 5000 → fiveK (highest matching)
        #expect(MilestoneDistance.detect(from: 7500) == .fiveK)
    }

    @Test("Detects half marathon")
    func detectHalfMarathon() {
        #expect(MilestoneDistance.detect(from: 21097) == .halfMarathon)
    }

    @Test("Detects marathon")
    func detectMarathon() {
        #expect(MilestoneDistance.detect(from: 42195) == .marathon)
    }

    @Test("Returns nil for distances below 5K")
    func noMilestone() {
        #expect(MilestoneDistance.detect(from: 3000) == nil)
        #expect(MilestoneDistance.detect(from: 4999) == nil)
    }

    @Test("Returns nil for nil distance")
    func nilDistance() {
        #expect(MilestoneDistance.detect(from: nil) == nil)
    }

    @Test("Returns nil for negative distance")
    func negativeDistance() {
        #expect(MilestoneDistance.detect(from: -5000) == nil)
    }

    @Test("Prioritizes marathon over shorter milestones")
    func marathonPriority() {
        // Marathon distance is ~42195, which shouldn't match 5K or 10K
        let result = MilestoneDistance.detect(from: 42195)
        #expect(result == .marathon)
    }
}
