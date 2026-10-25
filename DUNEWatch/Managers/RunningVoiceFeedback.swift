import Foundation
import Observation

@MainActor
protocol RunningVoiceSpeaking: AnyObject {
    func speak(_ text: String, language: String, volume: Float, onFinish: @escaping @MainActor () -> Void)
    func stop()
}

/// Short, optional spoken cues for a running workout on this Watch.
@MainActor
@Observable
final class RunningVoiceFeedback {
    enum Event {
        case started
        case paused
        case resumed
        case ended
        case split(distanceMeters: Int, durationSeconds: Double, paceSecondsPerKm: Double)
        case tooFast
        case tooSlow

        var isProgressCue: Bool {
            switch self {
            case .split, .tooFast, .tooSlow: true
            case .started, .paused, .resumed, .ended: false
            }
        }
    }

    private static let enabledKey = "runningVoiceFeedbackEnabled"
    private static let settingsPrefix = "runningFeedback."
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let speaker: any RunningVoiceSpeaking
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let language: String
    private var isSpeaking = false
    private var pendingProgress: Event?
    @ObservationIgnored private var tracker: RunningFeedbackTracker
    private var speechGeneration = 0

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { stop() }
            if isEnabled, !oldValue { tracker.restartPaceFeedback() }
        }
    }

    var settings: RunningFeedbackSettings {
        didSet {
            let normalized = settings.normalized
            if settings != normalized { settings = normalized }
            if oldValue.distanceIntervalMeters != normalized.distanceIntervalMeters {
                if case .some(.split) = pendingProgress { pendingProgress = nil }
            }
            if oldValue.paceAlertsEnabled != normalized.paceAlertsEnabled
                || oldValue.targetPaceSecondsPerKm != normalized.targetPaceSecondsPerKm
                || oldValue.paceToleranceSecondsPerKm != normalized.paceToleranceSecondsPerKm {
                if case .some(.tooFast) = pendingProgress { pendingProgress = nil }
                if case .some(.tooSlow) = pendingProgress { pendingProgress = nil }
            }
            persistSettings()
            tracker.updateSettings(normalized)
            if normalized.volume == 0 { stop() }
            if oldValue.volume == 0, normalized.volume > 0 {
                tracker.restartPaceFeedback()
            }
        }
    }

    init(
        defaults: UserDefaults = .standard,
        speaker: any RunningVoiceSpeaking,
        locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    ) {
        self.defaults = defaults
        self.speaker = speaker
        self.locale = locale
        switch locale.language.languageCode?.identifier {
        case "ko": self.language = "ko-KR"
        case "ja": self.language = "ja-JP"
        default: self.language = "en-US"
        }
        self.isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        let loadedSettings = Self.loadSettings(from: defaults)
        self.settings = loadedSettings
        self.tracker = RunningFeedbackTracker(settings: loadedSettings)
    }

    func resetProgress(distanceMeters: Double = 0, activeElapsed: Double = 0) {
        pendingProgress = nil
        tracker.resetProgress(distanceMeters: distanceMeters, activeElapsed: activeElapsed)
    }

    func processProgress(distanceMeters: Double, activeElapsed: Double) {
        for cue in tracker.processProgress(distanceMeters: distanceMeters, activeElapsed: activeElapsed) {
            switch cue {
            case .split(let distance, let duration, let pace):
                announce(event: .split(distanceMeters: distance, durationSeconds: duration, paceSecondsPerKm: pace))
            case .tooFast:
                announce(event: .tooFast)
            case .tooSlow:
                announce(event: .tooSlow)
            }
        }
    }

    func suspendProgress() {
        pendingProgress = nil
        tracker.suspendProgress()
    }

    func resumeProgress(distanceMeters: Double, activeElapsed: Double) {
        tracker.resumeProgress(distanceMeters: distanceMeters, activeElapsed: activeElapsed)
    }

    func announce(event: Event) {
        guard isEnabled, settings.volume > 0, let text = message(for: event) else { return }

        if isSpeaking {
            if event.isProgressCue {
                if case .some(.split) = pendingProgress, case .tooFast = event { return }
                if case .some(.split) = pendingProgress, case .tooSlow = event { return }
                pendingProgress = event
                return
            }
            speechGeneration += 1
            speaker.stop()
            isSpeaking = false
            pendingProgress = nil
        }

        isSpeaking = true
        speechGeneration += 1
        let generation = speechGeneration
        speaker.speak(text, language: language, volume: Float(settings.volume)) { [weak self] in
            guard let self, self.speechGeneration == generation else { return }
            self.isSpeaking = false
            guard let pending = self.pendingProgress else { return }
            self.pendingProgress = nil
            self.announce(event: pending)
        }
    }

    func stop() {
        speechGeneration += 1
        pendingProgress = nil
        isSpeaking = false
        speaker.stop()
    }

    func message(for event: Event) -> String? {
        switch event {
        case .started:
            return String(localized: "Run started.", locale: locale)
        case .paused:
            return String(localized: "Run paused.", locale: locale)
        case .resumed:
            return String(localized: "Run resumed.", locale: locale)
        case .ended:
            return String(localized: "Run finished.", locale: locale)
        case .split(let distance, let duration, let pace):
            guard distance > 0, duration.isFinite, duration > 0, duration <= 86_400,
                  pace.isFinite, pace > 0, pace < 3_600 else { return nil }
            let splitSeconds = Int(duration.rounded())
            let paceSeconds = Int(pace.rounded())
            let splitMinutes = splitSeconds / 60
            let splitRemainder = splitSeconds % 60
            let paceMinutes = paceSeconds / 60
            let paceRemainder = paceSeconds % 60
            return String(localized: "Split \(distance) meters. Time \(splitMinutes) minutes \(splitRemainder) seconds. Pace \(paceMinutes) minutes \(paceRemainder) seconds per kilometer.", locale: locale)
        case .tooFast:
            return String(localized: "Slow down. You are faster than your target pace.", locale: locale)
        case .tooSlow:
            return String(localized: "Speed up. You are slower than your target pace.", locale: locale)
        }
    }

    private static func loadSettings(from defaults: UserDefaults) -> RunningFeedbackSettings {
        let standard = RunningFeedbackSettings()
        func number(_ key: String, fallback: Double) -> Double {
            defaults.object(forKey: settingsPrefix + key) as? Double ?? fallback
        }
        return RunningFeedbackSettings(
            distanceIntervalMeters: number("distanceIntervalMeters", fallback: standard.distanceIntervalMeters),
            volume: number("volume", fallback: standard.volume),
            paceAlertsEnabled: defaults.object(forKey: settingsPrefix + "paceAlertsEnabled") as? Bool
                ?? standard.paceAlertsEnabled,
            targetPaceSecondsPerKm: number("targetPaceSecondsPerKm", fallback: standard.targetPaceSecondsPerKm),
            paceToleranceSecondsPerKm: number("paceToleranceSecondsPerKm", fallback: standard.paceToleranceSecondsPerKm)
        )
    }

    private func persistSettings() {
        defaults.set(settings.distanceIntervalMeters, forKey: Self.settingsPrefix + "distanceIntervalMeters")
        defaults.set(settings.volume, forKey: Self.settingsPrefix + "volume")
        defaults.set(settings.paceAlertsEnabled, forKey: Self.settingsPrefix + "paceAlertsEnabled")
        defaults.set(settings.targetPaceSecondsPerKm, forKey: Self.settingsPrefix + "targetPaceSecondsPerKm")
        defaults.set(settings.paceToleranceSecondsPerKm, forKey: Self.settingsPrefix + "paceToleranceSecondsPerKm")
    }
}
