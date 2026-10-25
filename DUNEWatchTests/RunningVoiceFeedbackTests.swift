import Foundation
import Testing
@testable import DUNEWatch

@Suite("Running voice feedback")
@MainActor
struct RunningVoiceFeedbackTests {
    @Test("Running events produce short localized cues")
    func eventMessages() {
        let (feedback, _) = makeFeedback()
        #expect(feedback.message(for: .started) == "Run started.")
        #expect(feedback.message(for: .paused) == "Run paused.")
        #expect(feedback.message(for: .resumed) == "Run resumed.")
        #expect(feedback.message(for: .ended) == "Run finished.")
        #expect(feedback.message(for: .split(distanceMeters: 3_000, durationSeconds: 300, paceSecondsPerKm: 305)) ==
            "Split 3,000 meters. Time 5 minutes 0 seconds. Pace 5 minutes 5 seconds per kilometer.")
    }

    @Test("Invalid distance cues are not spoken")
    func invalidSplit() {
        let (feedback, speaker) = makeFeedback()
        feedback.announce(event: .split(distanceMeters: 0, durationSeconds: 300, paceSecondsPerKm: 300))
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: .nan))
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: 0))
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: 3_600))
        feedback.announce(event: .split(distanceMeters: -1_000, durationSeconds: 300, paceSecondsPerKm: 300))
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: .infinity))
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: -.infinity))
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: -300))
        #expect(speaker.messages.isEmpty)
    }

    @Test("Only the newest split cue waits behind active speech")
    func replacesPendingSplit() {
        let (feedback, speaker) = makeFeedback()
        feedback.announce(event: .started)
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: 300))
        feedback.announce(event: .split(distanceMeters: 2_000, durationSeconds: 300, paceSecondsPerKm: 330))
        #expect(speaker.messages.count == 1)
        speaker.finish()
        #expect(speaker.messages.count == 2)
        #expect(speaker.messages[1].contains("Split 2,000 meters"))
    }

    @Test("A session event interrupts a pending distance cue")
    func interruptsPendingDistance() {
        let (feedback, speaker) = makeFeedback()
        feedback.announce(event: .started)
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: 300))
        feedback.announce(event: .paused)
        #expect(speaker.stopCount >= 1)
        speaker.finish()
        #expect(speaker.messages == ["Run started.", "Run paused."])
    }

    @Test("Stopping removes pending distance announcements")
    func stopClearsPendingDistance() {
        let (feedback, speaker) = makeFeedback()
        feedback.announce(event: .started)
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: 300))
        feedback.stop()
        speaker.finish()
        #expect(speaker.messages == ["Run started."])
        feedback.announce(event: .resumed)
        #expect(speaker.messages.last == "Run resumed.")
    }

    @Test("Disabling feedback persists and cancels speech")
    func disablingPersists() throws {
        let suite = "RunningVoiceFeedbackTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let speaker = MockRunningVoiceSpeaker()
        let feedback = RunningVoiceFeedback(defaults: defaults, speaker: speaker, locale: Locale(identifier: "en"))
        #expect(feedback.isEnabled)
        feedback.announce(event: .started)
        feedback.isEnabled = false
        feedback.announce(event: .paused)
        #expect(speaker.messages == ["Run started."])
        #expect(speaker.stopCount >= 1)
        #expect(!RunningVoiceFeedback(defaults: defaults, speaker: speaker).isEnabled)
    }

    @Test("Settings persist and volume is forwarded without changing system volume")
    func settingsAndVolume() throws {
        let suite = "RunningVoiceSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let speaker = MockRunningVoiceSpeaker()
        let feedback = RunningVoiceFeedback(defaults: defaults, speaker: speaker, locale: Locale(identifier: "en"))
        feedback.settings = RunningFeedbackSettings(
            distanceIntervalMeters: 500,
            volume: 0.4,
            paceAlertsEnabled: true,
            targetPaceSecondsPerKm: 330,
            paceToleranceSecondsPerKm: 30
        )
        feedback.announce(event: .started)
        #expect(speaker.volumes == [0.4])
        let restored = RunningVoiceFeedback(defaults: defaults, speaker: speaker)
        #expect(restored.settings.distanceIntervalMeters == 500)
        #expect(restored.settings.volume == 0.4)
        #expect(restored.settings.paceAlertsEnabled)
        #expect(restored.settings.targetPaceSecondsPerKm == 330)
        #expect(restored.settings.paceToleranceSecondsPerKm == 30)
        feedback.settings.volume = 0
        feedback.announce(event: .resumed)
        #expect(speaker.messages == ["Run started."])
    }

    @Test("Interval changes remove queued splits from the old setting")
    func intervalChangeClearsQueuedSplit() {
        let (feedback, speaker) = makeFeedback()
        feedback.announce(event: .started)
        feedback.announce(event: .split(distanceMeters: 1_000, durationSeconds: 300, paceSecondsPerKm: 300))
        feedback.settings.distanceIntervalMeters = 500
        speaker.finish()
        #expect(speaker.messages == ["Run started."])
    }

    @Test("Pace setting changes remove queued hints based on old targets")
    func paceChangeClearsQueuedHint() {
        let (feedback, speaker) = makeFeedback()
        feedback.announce(event: .started)
        feedback.announce(event: .tooFast)
        feedback.settings.targetPaceSecondsPerKm = 330
        speaker.finish()
        #expect(speaker.messages == ["Run started."])

        feedback.settings.paceAlertsEnabled = true
        feedback.announce(event: .resumed)
        feedback.announce(event: .tooSlow)
        feedback.settings.paceAlertsEnabled = false
        speaker.finish()
        #expect(speaker.messages == ["Run started.", "Run resumed."])
    }

    @Test("Split and pace alerts use localized cue text")
    func newCueText() {
        let (feedback, _) = makeFeedback()
        #expect(feedback.message(for: .split(distanceMeters: 500, durationSeconds: 150, paceSecondsPerKm: 300)) ==
            "Split 500 meters. Time 2 minutes 30 seconds. Pace 5 minutes 0 seconds per kilometer.")
        #expect(feedback.message(for: .tooFast) == "Slow down. You are faster than your target pace.")
        #expect(feedback.message(for: .tooSlow) == "Speed up. You are slower than your target pace.")
    }

    @Test("Audible feedback restarts pace readiness without losing split progress", arguments: [false, true])
    func unmutingRestartsPaceAlerts(useVolume: Bool) {
        let (feedback, speaker) = makeFeedback()
        feedback.settings = RunningFeedbackSettings(paceAlertsEnabled: true)
        if useVolume { feedback.settings.volume = 0 } else { feedback.isEnabled = false }
        for second in stride(from: 10.0, through: 40, by: 10) {
            feedback.processProgress(distanceMeters: second * 1_000 / 300, activeElapsed: second)
        }
        #expect(speaker.messages.isEmpty)
        if useVolume { feedback.settings.volume = 0.7 } else { feedback.isEnabled = true }
        for second in stride(from: 50.0, through: 80, by: 10) {
            feedback.processProgress(distanceMeters: second * 1_000 / 300, activeElapsed: second)
        }
        #expect(speaker.messages == ["Slow down. You are faster than your target pace."])
        speaker.finish()
        feedback.processProgress(distanceMeters: 1_000, activeElapsed: 300)
        #expect(speaker.messages.last ==
            "Split 1,000 meters. Time 5 minutes 0 seconds. Pace 5 minutes 0 seconds per kilometer.")
    }

    private func makeFeedback() -> (RunningVoiceFeedback, MockRunningVoiceSpeaker) {
        let speaker = MockRunningVoiceSpeaker()
        let defaults = UserDefaults(suiteName: "RunningVoiceFeedbackTests.\(UUID().uuidString)")!
        return (RunningVoiceFeedback(defaults: defaults, speaker: speaker, locale: Locale(identifier: "en")), speaker)
    }
}

@MainActor
private final class MockRunningVoiceSpeaker: RunningVoiceSpeaking {
    var messages: [String] = []
    var volumes: [Float] = []
    var stopCount = 0
    private var completion: (@MainActor () -> Void)?

    func speak(_ text: String, language: String, volume: Float, onFinish: @escaping @MainActor () -> Void) {
        messages.append(text)
        volumes.append(volume)
        completion = onFinish
    }

    func stop() {
        stopCount += 1
        completion = nil
    }

    func finish() {
        let current = completion
        completion = nil
        current?()
    }
}
