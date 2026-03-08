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

@Observable
@MainActor
final class VisionVoiceWorkoutEntryViewModel {
    var transcript: String = "" {
        didSet {
            guard transcript != oldValue else { return }
            draft = nil
            errorMessage = nil
        }
    }

    var draft: VisionVoiceWorkoutDraft?
    var isListening = false
    var infoMessage: String?
    var errorMessage: String?

    private let parser: VisionVoiceWorkoutCommandParser
    private let transcriber: any VisionVoiceWorkoutTranscribing
    private let localeIdentifier: String

    init(
        parser: VisionVoiceWorkoutCommandParser = VisionVoiceWorkoutCommandParser(),
        transcriber: any VisionVoiceWorkoutTranscribing = VisionVoiceWorkoutTranscriberFactory.makeDefault(),
        localeIdentifier: String = Locale.autoupdatingCurrent.identifier
    ) {
        self.parser = parser
        self.transcriber = transcriber
        self.localeIdentifier = localeIdentifier
        self.infoMessage = String(localized: "Manual text works even if speech permission is unavailable.")
    }

    var canParse: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var listeningButtonTitle: String {
        if isListening {
            return String(localized: "Stop Listening")
        }
        return String(localized: "Start Listening")
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
            errorMessage = nil
            infoMessage = draft.notes.first ?? String(localized: "Voice draft ready.")
        case .failure(let message):
            draft = nil
            errorMessage = message
        }
    }

    func clearFeedback() {
        errorMessage = nil
        infoMessage = nil
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

private enum VisionVoiceWorkoutTranscriberError: Error {
    case unavailable
}

#if os(visionOS)
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
