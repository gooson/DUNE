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

    // MARK: - Pace Formatting (verify the formatting logic used by WorkoutManager)

    @Test("Pace formatting returns correct format for valid pace")
    func formattedPaceValid() {
        // 5 min 30 sec per km = 330 seconds
        let pace: Double = 330
        let result = formatPace(pace)
        #expect(result == "5:30")
    }

    @Test("Pace formatting returns dash for zero")
    func formattedPaceZero() {
        #expect(formatPace(0) == "--:--")
    }

    @Test("Pace formatting returns dash for infinity")
    func formattedPaceInfinity() {
        #expect(formatPace(.infinity) == "--:--")
    }

    @Test("Pace formatting returns dash for over 1 hour")
    func formattedPaceOverHour() {
        #expect(formatPace(3601) == "--:--")
    }

    /// Mirrors the formatting logic in WorkoutManager.formattedPace.
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0, pace.isFinite, pace < 3600 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - resolveDistanceBased

    @Test("resolveDistanceBased: direct rawValue match")
    func resolveDirectMatch() {
        let type = WorkoutActivityType.resolveDistanceBased(from: "running", name: "")
        #expect(type == .running)
    }

    @Test("resolveDistanceBased: stem extraction for variant IDs")
    func resolveStemExtraction() {
        let type = WorkoutActivityType.resolveDistanceBased(from: "running-treadmill", name: "")
        #expect(type == .running)
    }

    @Test("resolveDistanceBased: name-based inference fallback")
    func resolveNameInference() {
        let type = WorkoutActivityType.resolveDistanceBased(from: "custom-id", name: "Outdoor Running")
        #expect(type == .running)
    }

    @Test("resolveDistanceBased: returns nil for non-distance exercise")
    func resolveNonDistance() {
        let type = WorkoutActivityType.resolveDistanceBased(from: "bench-press", name: "Bench Press")
        #expect(type == nil)
    }

    @Test("resolveDistanceBased: non-distance rawValue returns nil")
    func resolveNonDistanceRawValue() {
        let type = WorkoutActivityType.resolveDistanceBased(from: "yoga", name: "Yoga")
        #expect(type == nil)
    }

    // MARK: - Name-Based Inference

    @Test("Name-based inference resolves exercise names")
    func nameInferenceMatch() {
        #expect(WorkoutActivityType.infer(from: "Outdoor Running")?.isDistanceBased == true)
        #expect(WorkoutActivityType.infer(from: "Indoor Cycling")?.isDistanceBased == true)
        #expect(WorkoutActivityType.infer(from: "Swimming Laps")?.isDistanceBased == true)
    }

    @Test("Non-cardio exercise returns nil for inference")
    func nonCardioInference() {
        let type = WorkoutActivityType.infer(from: "Bench Press")
        #expect(type?.isDistanceBased != true)
    }

    // MARK: - iconName Coverage

    @Test("All distance-based types have valid iconName", arguments: [
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
    func distanceBasedTypesHaveIcon(type: WorkoutActivityType) {
        #expect(!type.iconName.isEmpty)
    }
}
