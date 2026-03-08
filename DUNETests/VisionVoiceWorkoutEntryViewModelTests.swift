import Foundation
import Testing
@testable import DUNE

private struct MockVisionVoiceWorkoutEntryLibrary: ExerciseLibraryQuerying {
    let exercises: [ExerciseDefinition]

    func allExercises() -> [ExerciseDefinition] {
        exercises
    }

    func exercise(byID id: String) -> ExerciseDefinition? {
        exercises.first { $0.id == id }
    }

    func search(query: String) -> [ExerciseDefinition] {
        []
    }

    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] {
        []
    }

    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] {
        []
    }

    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] {
        []
    }
}

@MainActor
private final class MockVisionVoiceWorkoutTranscriber: VisionVoiceWorkoutTranscribing {
    var authorizationStatus: VisionVoiceWorkoutAuthorizationStatus = .authorized
    var startCallCount = 0
    var stopCallCount = 0
    var transcriptHandler: (@MainActor (String) -> Void)?
    var failureHandler: (@MainActor (String) -> Void)?
    var stopHandler: (@MainActor () -> Void)?
    var shouldThrowOnStart = false

    func requestAuthorization() async -> VisionVoiceWorkoutAuthorizationStatus {
        authorizationStatus
    }

    func start(
        localeIdentifier: String,
        onTranscript: @escaping @MainActor (String) -> Void,
        onFailure: @escaping @MainActor (String) -> Void,
        onStop: @escaping @MainActor () -> Void
    ) throws {
        startCallCount += 1
        transcriptHandler = onTranscript
        failureHandler = onFailure
        stopHandler = onStop
        if shouldThrowOnStart {
            throw NSError(domain: "MockVisionVoiceWorkoutTranscriber", code: 1)
        }
    }

    func stop() {
        stopCallCount += 1
    }
}

@Suite("VisionVoiceWorkoutEntryViewModel")
@MainActor
struct VisionVoiceWorkoutEntryViewModelTests {
    @Test("Denied authorization falls back to manual transcript entry")
    func deniedAuthorizationUsesManualFallback() async {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        transcriber.authorizationStatus = .denied
        let viewModel = makeViewModel(transcriber: transcriber)

        await viewModel.startListening()

        #expect(viewModel.isListening == false)
        #expect(viewModel.infoMessage == String(localized: "Speech recognition permission was denied. Type the workout instead."))
        #expect(transcriber.startCallCount == 0)
    }

    @Test("Authorized listening stores transcript updates")
    func authorizedListeningReceivesTranscript() async {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)

        await viewModel.startListening()
        transcriber.transcriptHandler?("Bench Press 80kg 8 reps")

        #expect(viewModel.isListening)
        #expect(viewModel.infoMessage == String(localized: "Listening..."))
        #expect(viewModel.transcript == "Bench Press 80kg 8 reps")
        #expect(transcriber.startCallCount == 1)
    }

    @Test("reviewDraft stores a parsed draft on success")
    func reviewDraftStoresParsedResult() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)
        viewModel.transcript = "러닝 30분 5km"

        viewModel.reviewDraft()

        #expect(viewModel.draft?.exercise.id == "running")
        #expect(viewModel.draft?.durationSeconds == 1_800)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.infoMessage == String(localized: "Voice draft ready."))
    }

    @Test("reviewDraft surfaces parser failure when the transcript is incomplete")
    func reviewDraftSurfacesParserFailure() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)
        viewModel.transcript = "Bench Press 80kg"

        viewModel.reviewDraft()

        #expect(viewModel.draft == nil)
        #expect(viewModel.errorMessage == String(localized: "Add reps for this exercise draft."))
    }

    @Test("stopListening resets listening state and preserves the transcript")
    func stopListeningResetsState() async {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)

        await viewModel.startListening()
        transcriber.transcriptHandler?("Squat 100 5")
        viewModel.stopListening()

        #expect(viewModel.isListening == false)
        #expect(viewModel.transcript == "Squat 100 5")
        #expect(viewModel.infoMessage == String(localized: "Transcript updated. Review the draft when you're ready."))
        #expect(transcriber.stopCallCount == 1)
    }

    @Test("createValidatedRecord builds a strength history record")
    func createValidatedRecordBuildsStrengthRecord() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)
        viewModel.transcript = "Bench Press 176 lb 8 reps"
        viewModel.reviewDraft()

        guard let record = viewModel.createValidatedRecord() else {
            Issue.record("Expected a strength record")
            return
        }

        #expect(viewModel.isSaving)
        #expect(record.exerciseDefinitionID == "barbell-bench-press")
        #expect(record.exerciseType == "Barbell Bench Press")
        #expect(record.duration == 0)
        #expect(record.distance == nil)
        #expect(record.completedSets.count == 1)
        #expect(record.completedSets.first?.reps == 8)
        #expect(record.completedSets.first?.duration == nil)
        #expect(record.completedSets.first?.distance == nil)
        #expect(record.completedSets.first?.weight != nil)
        #expect(abs((record.completedSets.first?.weight ?? 0) - WeightUnit.lb.toKg(176)) < 0.001)

        viewModel.didFinishSaving()

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isDraftSaved)
        #expect(viewModel.canSave == false)
        #expect(viewModel.infoMessage == String(localized: "Saved to workout history."))
    }

    @Test("createValidatedRecord builds a cardio history record")
    func createValidatedRecordBuildsCardioRecord() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)
        viewModel.transcript = "러닝 30분 5km"
        viewModel.reviewDraft()

        guard let record = viewModel.createValidatedRecord() else {
            Issue.record("Expected a cardio record")
            return
        }

        #expect(viewModel.isSaving)
        #expect(record.exerciseDefinitionID == "running")
        #expect(record.exerciseType == "Running")
        #expect(record.duration == 1_800)
        #expect(record.distance == 5)
        #expect(record.completedSets.count == 1)
        #expect(record.completedSets.first?.reps == nil)
        #expect(record.completedSets.first?.duration == 1_800)
        #expect(record.completedSets.first?.distance == 5)
    }

    @Test("createValidatedRecord requires a reviewed draft")
    func createValidatedRecordRequiresReviewedDraft() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let viewModel = makeViewModel(transcriber: transcriber)
        viewModel.transcript = "Bench Press 176 lb 8 reps"

        let record = viewModel.createValidatedRecord()

        #expect(record == nil)
        #expect(viewModel.errorMessage == String(localized: "Review the voice draft before saving it."))
        #expect(viewModel.isSaving == false)
    }

    private func makeViewModel(
        transcriber: MockVisionVoiceWorkoutTranscriber
    ) -> VisionVoiceWorkoutEntryViewModel {
        VisionVoiceWorkoutEntryViewModel(
            parser: VisionVoiceWorkoutCommandParser(
                library: MockVisionVoiceWorkoutEntryLibrary(
                    exercises: [
                        makeExercise(
                            id: "barbell-bench-press",
                            name: "Barbell Bench Press",
                            localizedName: "바벨 벤치프레스",
                            aliases: ["Bench Press", "플랫 벤치"],
                            inputType: .setsRepsWeight,
                            category: .strength
                        ),
                        makeExercise(
                            id: "running",
                            name: "Running",
                            localizedName: "러닝",
                            aliases: ["Running", "러닝"],
                            inputType: .durationDistance,
                            category: .cardio,
                            cardioSecondaryUnit: .km
                        ),
                    ]
                )
            ),
            transcriber: transcriber,
            localeIdentifier: "ko_KR"
        )
    }

    private func makeExercise(
        id: String,
        name: String,
        localizedName: String,
        aliases: [String],
        inputType: ExerciseInputType,
        category: ExerciseCategory,
        cardioSecondaryUnit: CardioSecondaryUnit? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: localizedName,
            category: category,
            inputType: inputType,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 5.5,
            aliases: aliases,
            cardioSecondaryUnit: cardioSecondaryUnit
        )
    }
}
