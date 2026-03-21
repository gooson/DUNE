import AVFoundation

// MARK: - FormVoiceCoach

/// Provides real-time voice coaching during exercise form checks.
///
/// Monitors checkpoint evaluation results and speaks coaching cues via
/// `AVSpeechSynthesizer` with cooldown-based repetition suppression.
///
/// All public methods must be called from `@MainActor` (the owning ViewModel is `@MainActor`).
final class FormVoiceCoach: @unchecked Sendable {

    // MARK: - Types

    private enum CuePriority: Int, Comparable {
        case caution = 0
        case warning = 1

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Configuration

    /// Minimum interval between repeated cues for the same checkpoint.
    let cooldown: TimeInterval

    // MARK: - Dependencies

    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    // MARK: - State

    private var lastSpokenTimes: [String: Date] = [:]
    private var isEnabled = false
    private var cachedCheckpoints: [String: FormCheckpoint] = [:]
    private var cachedRuleID: String?

    /// Injectable clock for testing.
    private let now: () -> Date

    // MARK: - Init

    init(cooldown: TimeInterval = 5.0, now: @escaping () -> Date = { Date() }) {
        self.cooldown = cooldown
        self.now = now

        // Cache voice once at init
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let voiceLanguage: String
        switch languageCode {
        case "ko": voiceLanguage = "ko-KR"
        case "ja": voiceLanguage = "ja-JP"
        default:   voiceLanguage = "en-US"
        }
        self.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
    }

    // MARK: - Public API

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            configureAudioSession()
        } else {
            synthesizer.stopSpeaking(at: .immediate)
            deactivateAudioSession()
        }
    }

    /// Evaluates the current form state and speaks coaching cues as needed.
    func processFormState(_ state: ExerciseFormState, rule: ExerciseFormRule) {
        guard isEnabled else { return }

        // Early exit if already speaking — avoid building unnecessary collections.
        guard !synthesizer.isSpeaking else { return }

        // Cache checkpoint lookup per rule (invalidate on rule change).
        if cachedRuleID != rule.id {
            cachedCheckpoints.removeAll(keepingCapacity: true)
            for cp in rule.checkpoints {
                cachedCheckpoints[cp.name] = cp
            }
            cachedRuleID = rule.id
        }

        let currentTime = now()

        // Find the highest-priority actionable checkpoint without intermediate array.
        var bestName: String?
        var bestCue: String?
        var bestPriority: CuePriority?

        for result in state.checkpointResults {
            guard result.status == .caution || result.status == .warning else { continue }
            guard let checkpoint = cachedCheckpoints[result.checkpointName] else { continue }
            guard !checkpoint.coachingCue.isEmpty else { continue }

            // Cooldown check
            if let lastTime = lastSpokenTimes[result.checkpointName],
               currentTime.timeIntervalSince(lastTime) < cooldown {
                continue
            }

            let priority: CuePriority =
                result.status == .warning ? .warning : .caution

            if let existing = bestPriority, priority <= existing { continue }
            bestName = result.checkpointName
            bestCue = checkpoint.coachingCue
            bestPriority = priority
        }

        guard let name = bestName, let cue = bestCue else { return }

        speak(cue)
        lastSpokenTimes[name] = currentTime
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        lastSpokenTimes.removeAll()
        cachedCheckpoints.removeAll()
        cachedRuleID = nil
        deactivateAudioSession()
    }

    // MARK: - Internals

    private func speak(_ text: String) {
        let localizedText = String(localized: String.LocalizationValue(text))
        let utterance = AVSpeechUtterance(string: localizedText)
        utterance.rate = 0.55
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.1
        utterance.volume = 0.9
        utterance.voice = voice

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
