import Foundation
import Observation

#if os(visionOS)
import AVFoundation
import Speech
#endif

enum VisionVoiceWorkoutAuthorizationStatus: Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case unsupported
}

@MainActor
protocol VisionVoiceWorkoutTranscribing: AnyObject {
    func requestAuthorization() async -> VisionVoiceWorkoutAuthorizationStatus
    func start(
        localeIdentifier: String,
        onTranscript: @escaping @MainActor (String) -> Void,
        onFailure: @escaping @MainActor (String) -> Void,
        onStop: @escaping @MainActor () -> Void
    ) throws
    func stop()
}

@MainActor
protocol VisionVoiceWorkoutSpeaking: AnyObject {
    func speak(_ text: String, localeIdentifier: String)
    func stop()
}

@Observable
@MainActor
final class VisionVoiceWorkoutEntryViewModel {
    var transcript: String = "" {
        didSet {
            guard transcript != oldValue else { return }
            speaker.stop()
            draft = nil
            isDraftSaved = false
            errorMessage = nil
            if !isListening {
                infoMessage = nil
            }
        }
    }

    var draft: VisionVoiceWorkoutDraft?
    var isListening = false
    var isSaving = false
    var isDraftSaved = false
    var infoMessage: String?
    var errorMessage: String?

    private let parser: VisionVoiceWorkoutCommandParser
    private let transcriber: any VisionVoiceWorkoutTranscribing
    private let speaker: any VisionVoiceWorkoutSpeaking
    private let localeIdentifier: String

    init(
        parser: VisionVoiceWorkoutCommandParser = VisionVoiceWorkoutCommandParser(),
        transcriber: any VisionVoiceWorkoutTranscribing = VisionVoiceWorkoutTranscriberFactory.makeDefault(),
        speaker: any VisionVoiceWorkoutSpeaking = VisionVoiceWorkoutSpeakerFactory.makeDefault(),
        localeIdentifier: String = Locale.autoupdatingCurrent.identifier
    ) {
        self.parser = parser
        self.transcriber = transcriber
        self.speaker = speaker
        self.localeIdentifier = localeIdentifier
        self.infoMessage = String(localized: "Manual text works even if speech permission is unavailable.")
    }

    var canParse: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSave: Bool {
        draft != nil && !isSaving && !isDraftSaved
    }

    var listeningButtonTitle: String {
        if isListening {
            return String(localized: "Stop Listening")
        }
        return String(localized: "Start Listening")
    }

    var saveButtonTitle: String {
        if isDraftSaved {
            return String(localized: "Saved")
        }
        return String(localized: "Save to History")
    }

    func toggleListening() async {
        if isListening {
            stopListening()
            return
        }
        await startListening()
    }

    func startListening() async {
        errorMessage = nil
        speaker.stop()

        switch await transcriber.requestAuthorization() {
        case .authorized:
            break
        case .denied:
            isListening = false
            infoMessage = String(localized: "Speech recognition permission was denied. Type the workout instead.")
            return
        case .restricted:
            isListening = false
            infoMessage = String(localized: "Speech recognition is restricted on this device.")
            return
        case .unsupported:
            isListening = false
            infoMessage = String(localized: "Speech recognition is not available on this device.")
            return
        }

        do {
            try transcriber.start(
                localeIdentifier: localeIdentifier,
                onTranscript: { [weak self] transcript in
                    self?.transcript = transcript
                },
                onFailure: { [weak self] message in
                    self?.isListening = false
                    self?.errorMessage = message
                },
                onStop: { [weak self] in
                    self?.isListening = false
                    if self?.draft == nil {
                        self?.infoMessage = String(localized: "Transcript updated. Review the draft when you're ready.")
                    }
                }
            )
            isListening = true
            infoMessage = String(localized: "Listening...")
        } catch {
            isListening = false
            errorMessage = String(localized: "Speech capture could not start. Try again.")
        }
    }

    func stopListening() {
        transcriber.stop()
        isListening = false
        if draft == nil {
            infoMessage = String(localized: "Transcript updated. Review the draft when you're ready.")
        }
    }

    func reviewDraft() {
        switch parser.parse(transcript) {
        case .success(let draft):
            self.draft = draft
            isDraftSaved = false
            errorMessage = nil
            let reviewMessage = reviewFeedbackMessage(for: draft)
            infoMessage = [reviewMessage, draft.notes.first]
                .compactMap { $0 }
                .joined(separator: "\n")
            speakFeedback(reviewMessage)
        case .failure(let message):
            draft = nil
            isDraftSaved = false
            infoMessage = nil
            errorMessage = message
        }
    }

    func createValidatedRecord() -> ExerciseRecord? {
        guard !isSaving, !isDraftSaved else { return nil }
        guard let draft else {
            errorMessage = String(localized: "Review the voice draft before saving it.")
            return nil
        }

        isSaving = true
        errorMessage = nil
        return buildRecord(from: draft)
    }

    func didFinishSaving() {
        isSaving = false
        isDraftSaved = true
        errorMessage = nil
        if let draft {
            let saveMessage = savedFeedbackMessage(for: draft)
            infoMessage = saveMessage
            speakFeedback(saveMessage)
        } else {
            let fallbackMessage = String(localized: "Saved to workout history.")
            infoMessage = fallbackMessage
            speakFeedback(fallbackMessage)
        }
    }

    func clearFeedback() {
        errorMessage = nil
        infoMessage = nil
        speaker.stop()
    }

    func stopAudioFeedback() {
        speaker.stop()
    }

    func adjustReps(by delta: Int) {
        guard !isListening, let draft, let reps = draft.reps else { return }
        let updatedReps = max(1, reps + delta)
        guard updatedReps != reps else { return }
        applyEditedDraft(updatedDraft(from: draft, reps: updatedReps))
    }

    func adjustWeight(by delta: Int) {
        guard !isListening,
              let draft,
              let weight = draft.weight,
              let weightUnit = draft.weightUnit
        else { return }

        let step = weightUnit == .kg ? 2.5 : 5.0
        let updatedWeight = max(step, weight + Double(delta) * step)
        guard updatedWeight != weight else { return }
        applyEditedDraft(updatedDraft(from: draft, weight: updatedWeight))
    }

    func adjustDuration(by delta: Int) {
        guard !isListening, let draft, let durationSeconds = draft.durationSeconds else { return }
        let step: TimeInterval = 60
        let updatedDuration = max(step, durationSeconds + TimeInterval(delta) * step)
        guard updatedDuration != durationSeconds else { return }
        applyEditedDraft(updatedDraft(from: draft, durationSeconds: updatedDuration))
    }

    func adjustDistance(by delta: Int) {
        guard !isListening,
              let draft,
              let distance = draft.distance,
              let distanceUnit = draft.distanceUnit
        else { return }

        let step: Double
        switch distanceUnit {
        case .km:
            step = 0.5
        case .meters:
            step = 100
        case .miles:
            step = 0.25
        }

        let updatedDistance = max(step, distance + Double(delta) * step)
        guard updatedDistance != distance else { return }
        applyEditedDraft(updatedDraft(from: draft, distance: updatedDistance))
    }

    private func buildRecord(from draft: VisionVoiceWorkoutDraft) -> ExerciseRecord {
        let distanceKm = setDistance(for: draft)
        let record = ExerciseRecord(
            date: Date(),
            exerciseType: draft.exercise.name,
            duration: recordDuration(for: draft),
            distance: distanceKm,
            exerciseDefinitionID: draft.exercise.id,
            primaryMuscles: draft.exercise.primaryMuscles,
            secondaryMuscles: draft.exercise.secondaryMuscles,
            equipment: draft.exercise.equipment
        )

        let workoutSet = WorkoutSet(
            setNumber: 1,
            setType: .working,
            weight: setWeight(for: draft),
            reps: setReps(for: draft),
            duration: setDuration(for: draft),
            distance: distanceKm,
            intensity: nil,
            isCompleted: true,
            restDuration: nil
        )
        workoutSet.exerciseRecord = record
        record.sets = [workoutSet]

        return record
    }

    private func normalizedWeightKg(from draft: VisionVoiceWorkoutDraft) -> Double? {
        guard let weight = draft.weight else { return nil }
        let unit = draft.weightUnit ?? .kg
        return unit.toKg(weight)
    }

    private func setWeight(for draft: VisionVoiceWorkoutDraft) -> Double? {
        switch draft.exercise.inputType {
        case .setsRepsWeight, .setsReps:
            return normalizedWeightKg(from: draft)
        case .durationDistance, .durationIntensity, .roundsBased:
            return nil
        }
    }

    private func normalizedDistanceKm(from draft: VisionVoiceWorkoutDraft) -> Double? {
        guard let distance = draft.distance else { return nil }

        switch draft.distanceUnit {
        case .km, nil:
            return distance
        case .meters:
            return distance / 1_000.0
        case .miles:
            return distance * 1.609_344
        }
    }

    private func setDistance(for draft: VisionVoiceWorkoutDraft) -> Double? {
        switch draft.exercise.inputType {
        case .durationDistance:
            return normalizedDistanceKm(from: draft)
        case .setsRepsWeight, .setsReps, .durationIntensity, .roundsBased:
            return nil
        }
    }

    private func recordDuration(for draft: VisionVoiceWorkoutDraft) -> TimeInterval {
        switch draft.exercise.inputType {
        case .durationDistance, .durationIntensity, .roundsBased:
            return draft.durationSeconds ?? 0
        case .setsRepsWeight, .setsReps:
            return 0
        }
    }

    private func setDuration(for draft: VisionVoiceWorkoutDraft) -> TimeInterval? {
        switch draft.exercise.inputType {
        case .durationDistance, .durationIntensity, .roundsBased:
            return draft.durationSeconds
        case .setsRepsWeight, .setsReps:
            return nil
        }
    }

    private func setReps(for draft: VisionVoiceWorkoutDraft) -> Int? {
        switch draft.exercise.inputType {
        case .setsRepsWeight, .setsReps, .roundsBased:
            return draft.reps
        case .durationDistance, .durationIntensity:
            return nil
        }
    }

    private var currentLocale: Locale {
        Locale(identifier: localeIdentifier)
    }

    private func updatedDraft(
        from draft: VisionVoiceWorkoutDraft,
        reps: Int? = nil,
        weight: Double? = nil,
        durationSeconds: TimeInterval? = nil,
        distance: Double? = nil
    ) -> VisionVoiceWorkoutDraft {
        VisionVoiceWorkoutDraft(
            transcript: draft.transcript,
            exercise: draft.exercise,
            reps: reps ?? draft.reps,
            weight: weight ?? draft.weight,
            weightUnit: draft.weightUnit,
            durationSeconds: durationSeconds ?? draft.durationSeconds,
            distance: distance ?? draft.distance,
            distanceUnit: draft.distanceUnit,
            notes: draft.notes
        )
    }

    private func applyEditedDraft(_ draft: VisionVoiceWorkoutDraft) {
        self.draft = draft
        isSaving = false
        isDraftSaved = false
        errorMessage = nil
        speaker.stop()
        infoMessage = reviewFeedbackMessage(for: draft)
    }

    private func reviewFeedbackMessage(for draft: VisionVoiceWorkoutDraft) -> String {
        String(
            format: String(localized: "Ready to save %@."),
            locale: currentLocale,
            draftSummary(for: draft)
        )
    }

    private func savedFeedbackMessage(for draft: VisionVoiceWorkoutDraft) -> String {
        String(
            format: String(localized: "Saved %@."),
            locale: currentLocale,
            draftSummary(for: draft)
        )
    }

    private func draftSummary(for draft: VisionVoiceWorkoutDraft) -> String {
        let formatter = ListFormatter()
        formatter.locale = currentLocale

        let parts = [draft.primaryDisplayName(locale: currentLocale)] + metricSummaryParts(for: draft)
        return formatter.string(from: parts) ?? parts.joined(separator: ", ")
    }

    private func metricSummaryParts(for draft: VisionVoiceWorkoutDraft) -> [String] {
        var parts: [String] = []

        if let weight = draft.weight, let weightUnit = draft.weightUnit {
            parts.append("\(formattedNumber(weight)) \(weightUnit.displayName)")
        }
        if let reps = draft.reps {
            let formattedReps = reps.formatted(.number.locale(currentLocale))
            parts.append(
                String(
                    format: String(localized: "%@ reps"),
                    locale: currentLocale,
                    formattedReps
                )
            )
        }
        if let durationSeconds = draft.durationSeconds {
            parts.append(formattedDuration(durationSeconds))
        }
        if let distance = draft.distance, let distanceUnit = draft.distanceUnit {
            parts.append("\(formattedNumber(distance)) \(distanceUnit.displayName)")
        }

        return parts
    }

    private func formattedNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(currentLocale))
    }

    private func formattedDuration(_ durationSeconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .short
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = currentLocale
        formatter.calendar = calendar
        return formatter.string(from: durationSeconds) ?? "\(Int(durationSeconds))s"
    }

    private func speakFeedback(_ message: String) {
        guard !isListening, !message.isEmpty else { return }
        speaker.speak(message, localeIdentifier: localeIdentifier)
    }
}

private enum VisionVoiceWorkoutTranscriberFactory {
    @MainActor
    static func makeDefault() -> any VisionVoiceWorkoutTranscribing {
        #if os(visionOS)
        VisionSpeechWorkoutTranscriber()
        #else
        UnsupportedVisionVoiceWorkoutTranscriber()
        #endif
    }
}

private enum VisionVoiceWorkoutSpeakerFactory {
    @MainActor
    static func makeDefault() -> any VisionVoiceWorkoutSpeaking {
        #if os(visionOS)
        VisionSpeechWorkoutSpeaker()
        #else
        UnsupportedVisionVoiceWorkoutSpeaker()
        #endif
    }
}

@MainActor
private final class UnsupportedVisionVoiceWorkoutTranscriber: VisionVoiceWorkoutTranscribing {
    func requestAuthorization() async -> VisionVoiceWorkoutAuthorizationStatus {
        .unsupported
    }

    func start(
        localeIdentifier: String,
        onTranscript: @escaping @MainActor (String) -> Void,
        onFailure: @escaping @MainActor (String) -> Void,
        onStop: @escaping @MainActor () -> Void
    ) throws {
        throw VisionVoiceWorkoutTranscriberError.unavailable
    }

    func stop() {}
}

@MainActor
private final class UnsupportedVisionVoiceWorkoutSpeaker: VisionVoiceWorkoutSpeaking {
    func speak(_ text: String, localeIdentifier: String) {}
    func stop() {}
}

private enum VisionVoiceWorkoutTranscriberError: Error {
    case unavailable
}

#if os(visionOS)
@MainActor
private final class VisionSpeechWorkoutSpeaker: VisionVoiceWorkoutSpeaking {
    private let speechSynthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, localeIdentifier: String) {
        guard !text.isEmpty else { return }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(
            language: localeIdentifier.replacingOccurrences(of: "_", with: "-")
        )
        speechSynthesizer.speak(utterance)
    }

    func stop() {
        guard speechSynthesizer.isSpeaking else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}

@MainActor
private final class VisionSpeechWorkoutTranscriber: NSObject, VisionVoiceWorkoutTranscribing {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func requestAuthorization() async -> VisionVoiceWorkoutAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: Self.authorizationStatus(from: status))
            }
        }
    }

    func start(
        localeIdentifier: String,
        onTranscript: @escaping @MainActor (String) -> Void,
        onFailure: @escaping @MainActor (String) -> Void,
        onStop: @escaping @MainActor () -> Void
    ) throws {
        stop()

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw VisionVoiceWorkoutTranscriberError.unavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) {
            [weak self] buffer,
            _
            in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let transcript = result?.bestTranscription.formattedString,
                   !transcript.isEmpty {
                    onTranscript(transcript)
                }

                if let error {
                    AppLogger.ui.error("Vision speech recognition failed: \(error.localizedDescription)")
                    self.stop()
                    onFailure(String(localized: "Speech capture could not start. Try again."))
                    return
                }

                if result?.isFinal == true {
                    self.stop()
                    onStop()
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func authorizationStatus(
        from status: SFSpeechRecognizerAuthorizationStatus
    ) -> VisionVoiceWorkoutAuthorizationStatus {
        switch status {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .unsupported
        @unknown default:
            .unsupported
        }
    }
}
#endif
