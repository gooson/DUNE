import Foundation
import Testing
@testable import DUNE

@Suite("CardioSessionViewModel")
@MainActor
struct CardioSessionViewModelTests {

    // MARK: - Test Doubles

    private final class MockLocationTrackingService: LocationTrackingServiceProtocol, @unchecked Sendable {
        var totalDistanceMeters: Double
        var totalElevationGainMeters: Double
        var finalDistanceMeters: Double
        var shouldThrowStart = false

        init(
            totalDistanceMeters: Double = 0,
            totalElevationGainMeters: Double = 0,
            finalDistanceMeters: Double = 0
        ) {
            self.totalDistanceMeters = totalDistanceMeters
            self.totalElevationGainMeters = totalElevationGainMeters
            self.finalDistanceMeters = finalDistanceMeters
        }

        func startTracking() async throws {
            if shouldThrowStart {
                throw LocationTrackingError.notAuthorized
            }
        }

        func stopTracking() async -> Double {
            finalDistanceMeters
        }
    }

    private final class MockMotionTrackingService: MotionTrackingServiceProtocol, @unchecked Sendable {
        var latestSnapshot: MotionTrackingSnapshot
        var finalSnapshot: MotionTrackingSnapshot
        var shouldThrowStart = false

        init(
            latestSnapshot: MotionTrackingSnapshot = .empty,
            finalSnapshot: MotionTrackingSnapshot = .empty
        ) {
            self.latestSnapshot = latestSnapshot
            self.finalSnapshot = finalSnapshot
        }

        func startTracking(from startDate: Date) async throws {
            if shouldThrowStart {
                throw MotionTrackingError.notAuthorized
            }
        }

        func stopTracking() async -> MotionTrackingSnapshot {
            finalSnapshot
        }
    }

    private actor MockStepsService: StepsQuerying {
        var todaySteps: Double

        init(todaySteps: Double) {
            self.todaySteps = todaySteps
        }

        func setTodaySteps(_ value: Double) {
            todaySteps = value
        }

        func fetchSteps(for date: Date) async throws -> Double? { todaySteps }
        func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
        func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] { [] }
    }

    private actor MockVitalsService: VitalsQuerying {
        var vo2MaxValue: Double?
        var shouldThrow = false

        init(vo2MaxValue: Double? = nil) {
            self.vo2MaxValue = vo2MaxValue
        }

        func setThrow(_ value: Bool) {
            shouldThrow = value
        }

        func fetchLatestSpO2(withinDays days: Int) async throws -> VitalSample? { nil }
        func fetchLatestRespiratoryRate(withinDays days: Int) async throws -> VitalSample? { nil }
        func fetchLatestVO2Max(withinDays days: Int) async throws -> VitalSample? {
            if shouldThrow { throw HealthKitError.queryFailed("mock") }
            guard let value = vo2MaxValue else { return nil }
            return VitalSample(value: value, date: Date())
        }
        func fetchLatestHeartRateRecovery(withinDays days: Int) async throws -> VitalSample? { nil }
        func fetchLatestWristTemperature(withinDays days: Int) async throws -> VitalSample? { nil }
        func fetchSpO2Collection(days: Int) async throws -> [VitalSample] { [] }
        func fetchRespiratoryRateCollection(days: Int) async throws -> [VitalSample] { [] }
        func fetchVO2MaxHistory(days: Int) async throws -> [VitalSample] { [] }
        func fetchHeartRateRecoveryHistory(days: Int) async throws -> [VitalSample] { [] }
        func fetchWristTemperatureCollection(days: Int) async throws -> [VitalSample] { [] }
        func fetchWristTemperatureBaseline(days: Int) async throws -> Double? { nil }
    }

    // MARK: - Helpers

    private func makeExercise(
        id: String = "running",
        name: String = "Running"
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: "러닝",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps, .hamstrings],
            secondaryMuscles: [.calves],
            equipment: .bodyweight,
            metValue: 9.8,
            cardioSecondaryUnit: .km
        )
    }

    private func makeVM(
        id: String = "running",
        name: String = "Running",
        isOutdoor: Bool = true,
        activityType: WorkoutActivityType = .running,
        locationService: MockLocationTrackingService? = nil,
        motionService: MockMotionTrackingService? = nil,
        stepsService: StepsQuerying? = nil,
        vitalsService: VitalsQuerying? = nil
    ) -> CardioSessionViewModel {
        let exercise = makeExercise(id: id, name: name)
        let location = locationService ?? MockLocationTrackingService()
        let motion = motionService ?? MockMotionTrackingService()
        return CardioSessionViewModel(
            exercise: exercise,
            activityType: activityType,
            isOutdoor: isOutdoor,
            locationService: location,
            motionService: motion,
            stepsService: stepsService,
            vitalsService: vitalsService
        )
    }

    // MARK: - Initial State

    @Test("Initial state is idle")
    func initialStateIdle() {
        let vm = makeVM()
        #expect(vm.state == .idle)
        #expect(vm.startDate == nil)
        #expect(vm.elapsedSeconds == 0)
    }

    // MARK: - Record Creation

    @Test("createExerciseRecord returns nil when state is idle")
    func noRecordWhenIdle() {
        let vm = makeVM()
        let result = vm.createExerciseRecord()
        #expect(result == nil)
    }

    @Test("createExerciseRecord returns nil when state is running")
    func noRecordWhenRunning() {
        let vm = makeVM()
        vm.start()
        let result = vm.createExerciseRecord()
        #expect(result == nil)
    }

    @Test("Record has correct exerciseID")
    func recordExerciseID() async {
        let vm = makeVM(id: "cycling", name: "Cycling", activityType: .cycling)
        vm.start()
        try? await Task.sleep(for: .milliseconds(100))
        await vm.end()
        let record = vm.createExerciseRecord()
        #expect(record?.exerciseID == "cycling")
    }

    @Test("Record duration matches elapsed time")
    func recordDuration() async {
        let vm = makeVM()
        vm.start()
        try? await Task.sleep(for: .seconds(2))
        await vm.end()
        let record = vm.createExerciseRecord()
        #expect(record != nil)
        let duration = record?.duration ?? 0
        #expect(duration >= 1.5)
        #expect(duration < 4)
    }

    @Test("Record distanceKm is nil when no measured distance")
    func zeroDistanceIsNil() async {
        let vm = makeVM(isOutdoor: false)
        vm.start()
        try? await Task.sleep(for: .milliseconds(100))
        await vm.end()
        let record = vm.createExerciseRecord()
        #expect(record?.distanceKm == nil)
    }

    @Test("Record has correct category")
    func recordCategory() async {
        let vm = makeVM()
        vm.start()
        try? await Task.sleep(for: .milliseconds(100))
        await vm.end()
        let record = vm.createExerciseRecord()
        #expect(record?.category == .cardio)
    }

    @Test("Record includes motion step and cadence metrics")
    func recordIncludesMotionMetrics() async {
        let motion = MockMotionTrackingService(
            finalSnapshot: MotionTrackingSnapshot(
                stepCount: 6_500,
                distanceMeters: 4_300,
                currentPaceSecondsPerKm: 330,
                averagePaceSecondsPerKm: 345,
                cadenceStepsPerMinute: 168,
                floorsAscended: 12
            )
        )

        let vm = makeVM(isOutdoor: false, motionService: motion)
        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        await vm.end()

        let record = vm.createExerciseRecord()
        #expect(record?.stepCount == 6_500)
        #expect(record?.averageCadenceStepsPerMinute == 168)
        #expect(record?.averagePaceSecondsPerKm == 345)
        #expect(record?.floorsAscended == 12)
        #expect(record?.distanceKm == 4.3)
    }

    @Test("Uses motion distance fallback when GPS final distance is unavailable")
    func motionDistanceFallback() async {
        let location = MockLocationTrackingService(
            totalDistanceMeters: 0,
            totalElevationGainMeters: 0,
            finalDistanceMeters: 0
        )
        let motion = MockMotionTrackingService(
            finalSnapshot: MotionTrackingSnapshot(
                stepCount: 2_000,
                distanceMeters: 1_500,
                currentPaceSecondsPerKm: 420,
                averagePaceSecondsPerKm: 430,
                cadenceStepsPerMinute: 140,
                floorsAscended: 0
            )
        )

        let vm = makeVM(isOutdoor: true, locationService: location, motionService: motion)
        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        await vm.end()

        let record = vm.createExerciseRecord()
        #expect(record?.distanceKm == 1.5)
    }

    @Test("Elevation gain falls back to floors when direct elevation is unavailable")
    func floorsFallbackElevationGain() async {
        let motion = MockMotionTrackingService(
            finalSnapshot: MotionTrackingSnapshot(
                stepCount: 1_000,
                distanceMeters: 900,
                currentPaceSecondsPerKm: 500,
                averagePaceSecondsPerKm: 510,
                cadenceStepsPerMinute: 120,
                floorsAscended: 8
            )
        )

        let vm = makeVM(isOutdoor: false, motionService: motion)
        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        await vm.end()

        let record = vm.createExerciseRecord()
        #expect((record?.elevationGainMeters ?? 0) > 20)
    }

    // MARK: - Formatted Values

    @Test("formattedElapsed shows M:SS format")
    func formattedElapsedMinutes() {
        let vm = makeVM()
        #expect(vm.formattedElapsed == "0:00")
    }

    @Test("formattedPace returns dashes when no distance")
    func formattedPaceNoDist() {
        let vm = makeVM()
        #expect(vm.formattedPace == "--:--")
    }

    // MARK: - showsDistance

    @Test("showsDistance is true for running regardless of indoor/outdoor")
    func showsDistanceForDistanceType() {
        let outdoor = makeVM(isOutdoor: true)
        let indoor = makeVM(isOutdoor: false)
        #expect(outdoor.showsDistance == true)
        #expect(indoor.showsDistance == true)
    }

    // MARK: - Pause / Resume

    @Test("Pause changes state from running to paused")
    func pauseState() {
        let vm = makeVM()
        vm.start()
        vm.pause()
        #expect(vm.state == .paused)
    }

    @Test("Resume changes state from paused to running")
    func resumeState() {
        let vm = makeVM()
        vm.start()
        vm.pause()
        vm.resume()
        #expect(vm.state == .running)
    }

    @Test("Pause is no-op when idle")
    func pauseWhenIdle() {
        let vm = makeVM()
        vm.pause()
        #expect(vm.state == .idle)
    }

    @Test("Resume is no-op when idle")
    func resumeWhenIdle() {
        let vm = makeVM()
        vm.resume()
        #expect(vm.state == .idle)
    }

    @Test("End from paused state produces finished state")
    func endFromPaused() async {
        let vm = makeVM()
        vm.start()
        try? await Task.sleep(for: .milliseconds(100))
        vm.pause()
        await vm.end()
        #expect(vm.state == .finished)
    }

    @Test("Walking session computes step delta from session baseline")
    func walkingSessionStepDelta() async {
        let steps = MockStepsService(todaySteps: 1_200)
        let vm = makeVM(
            id: "walking",
            name: "Walking",
            isOutdoor: false,
            activityType: .walking,
            stepsService: steps
        )

        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(vm.walkingStepCount == 0)

        await steps.setTodaySteps(1_450)
        try? await Task.sleep(for: .milliseconds(150))
        await vm.end()

        #expect(vm.walkingStepCount == 250)
    }

    // MARK: - Cardio Fitness (VO2 Max)

    @Test("Record includes cardioFitnessVO2Max when available")
    func recordIncludesVO2Max() async {
        let vitals = MockVitalsService(vo2MaxValue: 42.5)
        let vm = makeVM(isOutdoor: false, vitalsService: vitals)
        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        await vm.end()

        #expect(vm.cardioFitnessVO2Max == 42.5)
        let record = vm.createExerciseRecord()
        #expect(record?.cardioFitnessVO2Max == 42.5)
    }

    @Test("Record cardioFitnessVO2Max is nil when not available")
    func recordVO2MaxNilWhenUnavailable() async {
        let vitals = MockVitalsService(vo2MaxValue: nil)
        let vm = makeVM(isOutdoor: false, vitalsService: vitals)
        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        await vm.end()

        #expect(vm.cardioFitnessVO2Max == nil)
        let record = vm.createExerciseRecord()
        #expect(record?.cardioFitnessVO2Max == nil)
    }

    @Test("VO2Max fetch failure does not block session end")
    func vo2MaxFetchFailureNonBlocking() async {
        let vitals = MockVitalsService()
        await vitals.setThrow(true)
        let vm = makeVM(isOutdoor: false, vitalsService: vitals)
        vm.start()
        try? await Task.sleep(for: .milliseconds(200))
        await vm.end()

        #expect(vm.state == .finished)
        #expect(vm.cardioFitnessVO2Max == nil)
    }
}
