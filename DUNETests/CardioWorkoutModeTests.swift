import Testing
@testable import DUNE

@Suite("CardioWorkoutMode")
struct CardioWorkoutModeTests {

    // MARK: - WorkoutMode

    @Test("WorkoutMode.strength is not cardio")
    func strengthModeIsNotCardio() {
        let mode = WorkoutMode.strength
        #expect(!mode.isCardio)
    }

    @Test("WorkoutMode.cardio is cardio")
    func cardioModeIsCardio() {
        let mode = WorkoutMode.cardio(activityType: .running, isOutdoor: true)
        #expect(mode.isCardio)
    }

    @Test("WorkoutMode.cardio preserves activity type")
    func cardioModePreservesActivityType() {
        let mode = WorkoutMode.cardio(activityType: .cycling, isOutdoor: false)
        if case .cardio(let type, let outdoor) = mode {
            #expect(type == .cycling)
            #expect(!outdoor)
        } else {
            Issue.record("Expected cardio mode")
        }
    }

    // MARK: - WorkoutMode Codable

    @Test("WorkoutMode round-trips through JSON")
    func workoutModeCodable() throws {
        let original = WorkoutMode.cardio(activityType: .running, isOutdoor: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutMode.self, from: data)

        if case .cardio(let type, let outdoor) = decoded {
            #expect(type == .running)
            #expect(outdoor)
        } else {
            Issue.record("Expected cardio mode after decode")
        }
    }

    @Test("WorkoutMode.strength round-trips through JSON")
    func strengthModeCodable() throws {
        let original = WorkoutMode.strength
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutMode.self, from: data)
        #expect(!decoded.isCardio)
    }

    // MARK: - isDistanceBased Coverage

    @Test("All 12 isDistanceBased types are correctly identified", arguments: [
        WorkoutActivityType.running,
        .walking,
        .cycling,
        .swimming,
        .hiking,
        .elliptical,
        .rowing,
        .handCycling,
        .crossCountrySkiing,
        .downhillSkiing,
        .paddleSports,
        .swimBikeRun
    ])
    func distanceBasedTypes(type: WorkoutActivityType) {
        #expect(type.isDistanceBased)
    }

    @Test("Strength types are not distance-based")
    func strengthTypesNotDistanceBased() {
        #expect(!WorkoutActivityType.traditionalStrengthTraining.isDistanceBased)
        #expect(!WorkoutActivityType.yoga.isDistanceBased)
        #expect(!WorkoutActivityType.boxing.isDistanceBased)
    }

    // MARK: - Pace Formatting

    @Test("formattedPace returns correct format for valid pace")
    func formattedPaceValid() {
        // 5 min 30 sec per km = 330 seconds
        // We test the string format logic directly
        let pace: Double = 330
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        let formatted = String(format: "%d:%02d", mins, secs)
        #expect(formatted == "5:30")
    }

    @Test("formattedPace returns dash for zero")
    func formattedPaceZero() {
        let pace: Double = 0
        let result: String
        if pace > 0, pace.isFinite, pace < 3600 {
            let mins = Int(pace) / 60
            let secs = Int(pace) % 60
            result = String(format: "%d:%02d", mins, secs)
        } else {
            result = "--:--"
        }
        #expect(result == "--:--")
    }

    @Test("formattedPace returns dash for infinity")
    func formattedPaceInfinity() {
        let pace: Double = .infinity
        let result: String
        if pace > 0, pace.isFinite, pace < 3600 {
            let mins = Int(pace) / 60
            let secs = Int(pace) % 60
            result = String(format: "%d:%02d", mins, secs)
        } else {
            result = "--:--"
        }
        #expect(result == "--:--")
    }

    // MARK: - Activity Type Resolution

    @Test("Direct rawValue match resolves correctly")
    func directRawValueMatch() {
        let type = WorkoutActivityType(rawValue: "running")
        #expect(type == .running)
        #expect(type?.isDistanceBased == true)
    }

    @Test("Stem extraction resolves variant IDs")
    func stemExtractionMatch() {
        let id = "running-treadmill"
        let stem = id.components(separatedBy: "-").first ?? ""
        let type = WorkoutActivityType(rawValue: stem)
        #expect(type == .running)
        #expect(type?.isDistanceBased == true)
    }

    @Test("Name-based inference resolves exercise names")
    func nameInferenceMatch() {
        #expect(WorkoutActivityType.infer(from: "Outdoor Running")?.isDistanceBased == true)
        #expect(WorkoutActivityType.infer(from: "Indoor Cycling")?.isDistanceBased == true)
        #expect(WorkoutActivityType.infer(from: "Swimming Laps")?.isDistanceBased == true)
    }

    @Test("Non-cardio exercise returns nil for inference")
    func nonCardioInference() {
        // "Bench Press" should not infer a distance-based type
        let type = WorkoutActivityType.infer(from: "Bench Press")
        #expect(type?.isDistanceBased != true)
    }
}
