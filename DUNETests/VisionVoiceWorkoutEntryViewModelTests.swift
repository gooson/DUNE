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

@MainActor
private final class MockVisionVoiceWorkoutSpeaker: VisionVoiceWorkoutSpeaking {
    var spokenMessages: [String] = []
    var localeIdentifiers: [String] = []
    var stopCallCount = 0

    func speak(_ text: String, localeIdentifier: String) {
        spokenMessages.append(text)
        localeIdentifiers.append(localeIdentifier)
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
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker)

        await viewModel.startListening()

        #expect(viewModel.isListening == false)
        #expect(viewModel.infoMessage == String(localized: "Speech recognition permission was denied. Type the workout instead."))
        #expect(transcriber.startCallCount == 0)
        #expect(speaker.stopCallCount == 1)
    }

    @Test("Authorized listening stores transcript updates")
    func authorizedListeningReceivesTranscript() async {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker)

        await viewModel.startListening()
        transcriber.transcriptHandler?("Bench Press 80kg 8 reps")

        #expect(viewModel.isListening)
        #expect(viewModel.infoMessage == String(localized: "Listening..."))
        #expect(viewModel.transcript == "Bench Press 80kg 8 reps")
        #expect(transcriber.startCallCount == 1)
        #expect(speaker.stopCallCount == 1)
    }

    @Test("reviewDraft stores a parsed draft and announces localized confirmation")
    func reviewDraftStoresParsedResult() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let localeIdentifier = "ko_KR"
        let viewModel = makeViewModel(
            transcriber: transcriber,
            speaker: speaker,
            localeIdentifier: localeIdentifier
        )
        viewModel.transcript = "러닝 30분 5km"

        viewModel.reviewDraft()

        guard let draft = viewModel.draft else {
            Issue.record("Expected a parsed cardio draft")
            return
        }

        let expectedMessage = expectedReviewMessage(for: draft, localeIdentifier: localeIdentifier)

        #expect(draft.exercise.id == "running")
        #expect(draft.durationSeconds == 1_800)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.infoMessage == expectedMessage)
        #expect(speaker.spokenMessages == [expectedMessage])
        #expect(speaker.localeIdentifiers == [localeIdentifier])
    }

    @Test("reviewDraft surfaces parser failure when the transcript is incomplete")
    func reviewDraftSurfacesParserFailure() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker)
        viewModel.transcript = "Bench Press 80kg"

        viewModel.reviewDraft()

        #expect(viewModel.draft == nil)
        #expect(viewModel.errorMessage == String(localized: "Add reps for this exercise draft."))
        #expect(speaker.spokenMessages.isEmpty)
    }

    @Test("stopListening resets listening state and preserves the transcript")
    func stopListeningResetsState() async {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker)

        await viewModel.startListening()
        transcriber.transcriptHandler?("Squat 100 5")
        viewModel.stopListening()

        #expect(viewModel.isListening == false)
        #expect(viewModel.transcript == "Squat 100 5")
        #expect(viewModel.infoMessage == String(localized: "Transcript updated. Review the draft when you're ready."))
        #expect(transcriber.stopCallCount == 1)
        #expect(speaker.spokenMessages.isEmpty)
    }

    @Test("createValidatedRecord builds a strength history record")
    func createValidatedRecordBuildsStrengthRecord() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let localeIdentifier = "en_US"
        let viewModel = makeViewModel(
            transcriber: transcriber,
            speaker: speaker,
            localeIdentifier: localeIdentifier
        )
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

        guard let draft = viewModel.draft else {
            Issue.record("Expected a parsed draft to remain after save")
            return
        }

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isDraftSaved)
        #expect(viewModel.canSave == false)
        #expect(viewModel.infoMessage == expectedSavedMessage(for: draft, localeIdentifier: localeIdentifier))
        #expect(speaker.spokenMessages.last == expectedSavedMessage(for: draft, localeIdentifier: localeIdentifier))
    }

    @Test("createValidatedRecord builds a cardio history record")
    func createValidatedRecordBuildsCardioRecord() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker)
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
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker)
        viewModel.transcript = "Bench Press 176 lb 8 reps"

        let record = viewModel.createValidatedRecord()

        #expect(record == nil)
        #expect(viewModel.errorMessage == String(localized: "Review the voice draft before saving it."))
        #expect(viewModel.isSaving == false)
    }

    @Test("Adjusting a saved strength draft re-enables saving and updates mapped values")
    func adjustingStrengthDraftReenablesSaving() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let localeIdentifier = "en_US"
        let viewModel = makeViewModel(
            transcriber: transcriber,
            speaker: speaker,
            localeIdentifier: localeIdentifier
        )
        viewModel.transcript = "Bench Press 176 lb 8 reps"
        viewModel.reviewDraft()
        _ = viewModel.createValidatedRecord()
        viewModel.didFinishSaving()

        viewModel.adjustWeight(by: 1)
        viewModel.adjustReps(by: 1)

        guard let draft = viewModel.draft,
              let record = viewModel.createValidatedRecord()
        else {
            Issue.record("Expected adjusted strength draft and record")
            return
        }

        #expect(draft.weight == 181)
        #expect(draft.reps == 9)
        #expect(viewModel.isDraftSaved == false)
        #expect(viewModel.infoMessage == expectedReviewMessage(for: draft, localeIdentifier: localeIdentifier))
        #expect(record.completedSets.first?.reps == 9)
        #expect(abs((record.completedSets.first?.weight ?? 0) - WeightUnit.lb.toKg(181)) < 0.001)
    }

    @Test("Adjusting a cardio draft updates duration and distance before save")
    func adjustingCardioDraftUpdatesMetrics() {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let localeIdentifier = "ko_KR"
        let viewModel = makeViewModel(
            transcriber: transcriber,
            speaker: speaker,
            localeIdentifier: localeIdentifier
        )
        viewModel.transcript = "러닝 30분 5km"
        viewModel.reviewDraft()

        viewModel.adjustDuration(by: 1)
        viewModel.adjustDistance(by: -1)

        guard let draft = viewModel.draft,
              let record = viewModel.createValidatedRecord()
        else {
            Issue.record("Expected adjusted cardio draft and record")
            return
        }

        #expect(draft.durationSeconds == 1_860)
        #expect(draft.distance == 4.5)
        #expect(viewModel.infoMessage == expectedReviewMessage(for: draft, localeIdentifier: localeIdentifier))
        #expect(record.duration == 1_860)
        #expect(record.distance == 4.5)
        #expect(record.completedSets.first?.duration == 1_860)
        #expect(record.completedSets.first?.distance == 4.5)
    }

    @Test("Reviewing while listening updates text feedback without speaking")
    func reviewDraftWhileListeningSkipsSpeechFeedback() async {
        let transcriber = MockVisionVoiceWorkoutTranscriber()
        let speaker = MockVisionVoiceWorkoutSpeaker()
        let viewModel = makeViewModel(transcriber: transcriber, speaker: speaker, localeIdentifier: "en_US")

        await viewModel.startListening()
        viewModel.transcript = "Bench Press 176 lb 8 reps"

        viewModel.reviewDraft()

        #expect(viewModel.draft != nil)
        #expect(speaker.spokenMessages.isEmpty)
    }

    private func makeViewModel(
        transcriber: MockVisionVoiceWorkoutTranscriber,
        speaker: MockVisionVoiceWorkoutSpeaker,
        localeIdentifier: String = "ko_KR"
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
            speaker: speaker,
            localeIdentifier: localeIdentifier
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

    private func expectedReviewMessage(
        for draft: VisionVoiceWorkoutDraft,
        localeIdentifier: String
    ) -> String {
        String(
            format: String(localized: "Ready to save %@."),
            locale: Locale(identifier: localeIdentifier),
            expectedSummary(for: draft, localeIdentifier: localeIdentifier)
        )
    }

    private func expectedSavedMessage(
        for draft: VisionVoiceWorkoutDraft,
        localeIdentifier: String
    ) -> String {
        String(
            format: String(localized: "Saved %@."),
            locale: Locale(identifier: localeIdentifier),
            expectedSummary(for: draft, localeIdentifier: localeIdentifier)
        )
    }

    private func expectedSummary(
        for draft: VisionVoiceWorkoutDraft,
        localeIdentifier: String
    ) -> String {
        let locale = Locale(identifier: localeIdentifier)
        let formatter = ListFormatter()
        formatter.locale = locale

        var parts = [draft.primaryDisplayName(locale: locale)]
        if let weight = draft.weight, let weightUnit = draft.weightUnit {
            parts.append("\(formattedNumber(weight, localeIdentifier: localeIdentifier)) \(weightUnit.displayName)")
        }
        if let reps = draft.reps {
            parts.append(
                String(
                    format: String(localized: "%@ reps"),
                    locale: locale,
                    reps.formatted(.number.locale(locale))
                )
            )
        }
        if let durationSeconds = draft.durationSeconds {
            parts.append(formattedDuration(durationSeconds, localeIdentifier: localeIdentifier))
        }
        if let distance = draft.distance, let distanceUnit = draft.distanceUnit {
            parts.append("\(formattedNumber(distance, localeIdentifier: localeIdentifier)) \(distanceUnit.displayName)")
        }

        return formatter.string(from: parts) ?? parts.joined(separator: ", ")
    }

    private func formattedNumber(_ value: Double, localeIdentifier: String) -> String {
        let locale = Locale(identifier: localeIdentifier)
        return value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    private func formattedDuration(
        _ durationSeconds: TimeInterval,
        localeIdentifier: String
    ) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .short
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Locale(identifier: localeIdentifier)
        formatter.calendar = calendar
        return formatter.string(from: durationSeconds) ?? "\(Int(durationSeconds))s"
    }
}
