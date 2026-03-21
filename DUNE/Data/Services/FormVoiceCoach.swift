import AVFoundation

/// Provides real-time voice coaching during exercise form checks.
///
/// Monitors checkpoint evaluation results and speaks coaching cues via
/// `AVSpeechSynthesizer` with cooldown-based repetition suppression.
final class FormVoiceCoach: @unchecked Sendable {

    // MARK: - Configuration

    /// Minimum interval between repeated cues for the same checkpoint.
    let cooldown: TimeInterval

    // MARK: - Dependencies

    private let synthesizer = AVSpeechSynthesizer()
    private let voiceLanguage: String

    // MARK: - State

    private var lastSpokenTimes: [String: Date] = [:]
    private var isEnabled = false

    /// Injectable clock for testing.
    private let now: () -> Date

    // MARK: - Init

    init(cooldown: TimeInterval = 5.0, now: @escaping () -> Date = { Date() }) {
        self.cooldown = cooldown
        self.now = now

        // Determine voice language from current locale
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch languageCode {
        case "ko": voiceLanguage = "ko-KR"
        case "ja": voiceLanguage = "ja-JP"
        default:   voiceLanguage = "en-US"
        }
    }

    // MARK: - Public API

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            configureAudioSession()
        } else {
            stop()
        }
    }

    /// Evaluates the current form state and speaks coaching cues as needed.
    func processFormState(_ state: ExerciseFormState, rule: ExerciseFormRule) {
        guard isEnabled else { return }

        let currentTime = now()

        // Build a lookup from checkpoint name to its rule definition.
        let checkpointsByName = Dictionary(
            rule.checkpoints.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Collect messages needing speech, sorted by priority (warning first).
        var messages: [FormCoachingMessage] = []

        for result in state.checkpointResults {
            guard result.status == .caution || result.status == .warning else { continue }
            guard let checkpoint = checkpointsByName[result.checkpointName] else { continue }
            guard checkpoint.coachingCue.isEmpty == false else { continue }

            // Cooldown check
            if let lastTime = lastSpokenTimes[result.checkpointName],
               currentTime.timeIntervalSince(lastTime) < cooldown {
                continue
            }

            let priority: FormCoachingMessage.Priority =
                result.status == .warning ? .warning : .caution
            messages.append(FormCoachingMessage(
                checkpointName: result.checkpointName,
                message: checkpoint.coachingCue,
                priority: priority
            ))
        }

        // Speak highest priority message only (avoid message flooding).
        guard let topMessage = messages.max(by: { $0.priority < $1.priority }) else { return }

        // Don't queue if already speaking — skip to avoid delay buildup.
        guard !synthesizer.isSpeaking else { return }

        speak(topMessage.message)
        lastSpokenTimes[topMessage.checkpointName] = currentTime
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        lastSpokenTimes.removeAll()
        deactivateAudioSession()
    }

    // MARK: - Internals

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.55
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.1
        utterance.volume = 0.9

        if let voice = AVSpeechSynthesisVoice(language: voiceLanguage) {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .duckOthers)
            try session.setActive(true)
        } catch {
            // Audio session configuration is best-effort; coaching degrades gracefully.
        }
    }

    private func deactivateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Best-effort deactivation.
        }
    }
}
