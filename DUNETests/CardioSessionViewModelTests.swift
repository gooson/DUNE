import Foundation
import Testing
@testable import DUNE

@Suite("CardioSessionViewModel")
@MainActor
struct CardioSessionViewModelTests {

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
        isOutdoor: Bool = true
    ) -> CardioSessionViewModel {
        let exercise = makeExercise(id: id, name: name)
        return CardioSessionViewModel(
            exercise: exercise,
            activityType: .running,
            isOutdoor: isOutdoor
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
        let vm = makeVM(id: "cycling", name: "Cycling")
        vm.start()
        // Let timer tick
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
        // Should be approximately 2 seconds (allow tolerance)
        #expect(duration >= 1.5)
        #expect(duration < 4)
    }

    @Test("Record distanceKm is nil when no GPS distance")
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

    // MARK: - Formatted Values

    @Test("formattedElapsed shows M:SS format")
    func formattedElapsedMinutes() {
        let vm = makeVM()
        // formattedElapsed reads elapsedSeconds which is 0 initially
        #expect(vm.formattedElapsed == "0:00")
    }

    @Test("formattedPace returns dashes when no distance")
    func formattedPaceNoDist() {
        let vm = makeVM()
        #expect(vm.formattedPace == "--:--")
    }

    // MARK: - showsDistance

    @Test("showsDistance is true for outdoor distance-based activity")
    func showsDistanceOutdoor() {
        let vm = makeVM(isOutdoor: true)
        #expect(vm.showsDistance == true)
    }

    @Test("showsDistance is false for indoor")
    func showsDistanceIndoor() {
        let vm = makeVM(isOutdoor: false)
        #expect(vm.showsDistance == false)
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
}
