import Foundation
import Testing
@testable import DUNEWatch

@Suite("Running feedback settings")
struct RunningFeedbackSettingsTests {
    @Test("Default options are conservative")
    func defaults() {
        let settings = RunningFeedbackSettings()
        #expect(settings.distanceIntervalMeters == 1_000)
        #expect(settings.volume == 1)
        #expect(!settings.paceAlertsEnabled)
        #expect(settings.targetPaceSecondsPerKm == 360)
        #expect(settings.paceToleranceSecondsPerKm == 15)
    }

    @Test("Invalid and nonfinite settings are normalized")
    func normalization() {
        let settings = RunningFeedbackSettings(
            distanceIntervalMeters: .nan,
            volume: .infinity,
            paceAlertsEnabled: true,
            targetPaceSecondsPerKm: -.infinity,
            paceToleranceSecondsPerKm: .nan
        )
        #expect(settings.distanceIntervalMeters == 1_000)
        #expect(settings.volume == 1)
        #expect(settings.paceAlertsEnabled)
        #expect(settings.targetPaceSecondsPerKm == 360)
        #expect(settings.paceToleranceSecondsPerKm == 15)
        #expect(RunningFeedbackSettings(distanceIntervalMeters: 750, volume: -1,
                                        targetPaceSecondsPerKm: 1, paceToleranceSecondsPerKm: 100)
            == RunningFeedbackSettings(distanceIntervalMeters: 1_000, volume: 0,
                                       targetPaceSecondsPerKm: 120, paceToleranceSecondsPerKm: 60))
    }
}

@Suite("Running feedback tracker")
struct RunningFeedbackTrackerTests {
    @Test("Each supported interval uses real split duration")
    func intervalBoundaries() {
        for interval in [500.0, 1_000, 2_000] {
            var tracker = RunningFeedbackTracker(settings: .init(distanceIntervalMeters: interval))
            #expect(tracker.processProgress(distanceMeters: interval - 1, activeElapsed: 9).isEmpty)
            let cues = tracker.processProgress(distanceMeters: interval, activeElapsed: 10)
            guard case .some(.split(let meters, let duration, let pace)) = cues.first else {
                Issue.record("Expected split at \(interval) meters")
                continue
            }
            #expect(meters == Int(interval))
            #expect(duration == 10)
            #expect(pace == 10_000 / interval)
        }
    }

    @Test("Sparse crossing announces only the newest complete interval")
    func sparseCrossing() {
        var tracker = RunningFeedbackTracker()
        let cues = tracker.processProgress(distanceMeters: 2_100, activeElapsed: 10)
        guard case .some(.split(let meters, let duration, _)) = cues.first else {
            Issue.record("Expected split")
            return
        }
        #expect(cues.count == 1)
        #expect(meters == 1_000)
        #expect(abs(duration - 10_000 / 2_100) < 0.001)
    }

    @Test("Resume at unchanged distance preserves the active split")
    func pauseUsesActiveTime() {
        var tracker = RunningFeedbackTracker()
        #expect(tracker.processProgress(distanceMeters: 500, activeElapsed: 10).isEmpty)
        tracker.suspendProgress()
        #expect(tracker.processProgress(distanceMeters: 900, activeElapsed: 10).isEmpty)
        tracker.resumeProgress(distanceMeters: 500, activeElapsed: 10)
        let cues = tracker.processProgress(distanceMeters: 1_000, activeElapsed: 20)
        guard case .some(.split(_, let duration, _)) = cues.first else {
            Issue.record("Expected active-time split")
            return
        }
        #expect(duration == 20)
    }

    @Test("Resume with a distance correction rebases the partial split")
    func resumeCorrection() {
        var tracker = RunningFeedbackTracker()
        _ = tracker.processProgress(distanceMeters: 500, activeElapsed: 10)
        tracker.suspendProgress()
        tracker.resumeProgress(distanceMeters: 600, activeElapsed: 10)
        #expect(tracker.processProgress(distanceMeters: 1_000, activeElapsed: 20).isEmpty)
        #expect(tracker.processProgress(distanceMeters: 1_600, activeElapsed: 30).count == 1)
    }

    @Test("Recovery and interval changes skip partial retrospective splits")
    func rebasing() {
        var tracker = RunningFeedbackTracker()
        tracker.resetProgress(distanceMeters: 750, activeElapsed: 300)
        #expect(tracker.processProgress(distanceMeters: 1_000, activeElapsed: 310).isEmpty)
        let first = tracker.processProgress(distanceMeters: 2_000, activeElapsed: 320)
        #expect(first.count == 1)
        _ = tracker.processProgress(distanceMeters: 2_100, activeElapsed: 325)
        tracker.updateSettings(.init(distanceIntervalMeters: 500))
        #expect(tracker.processProgress(distanceMeters: 2_500, activeElapsed: 330).isEmpty)
        #expect(tracker.processProgress(distanceMeters: 3_000, activeElapsed: 340).count == 1)
    }

    @Test("Stale, invalid, and regressing samples reset safely")
    func invalidSamples() {
        var tracker = RunningFeedbackTracker()
        #expect(tracker.processProgress(distanceMeters: .nan, activeElapsed: 5).isEmpty)
        #expect(tracker.processProgress(distanceMeters: 900, activeElapsed: 10).isEmpty)
        #expect(tracker.processProgress(distanceMeters: 1_000, activeElapsed: 30).isEmpty)
        #expect(tracker.processProgress(distanceMeters: 500, activeElapsed: 31).isEmpty)
        #expect(tracker.processProgress(distanceMeters: 1_000, activeElapsed: 32).isEmpty)
    }

    @Test("A stale pace sample still completes a monotonic distance split")
    func stalePaceStillSplits() {
        var tracker = RunningFeedbackTracker(settings: .init(paceAlertsEnabled: true))
        #expect(tracker.processProgress(distanceMeters: 900, activeElapsed: 10).isEmpty)
        let cues = tracker.processProgress(distanceMeters: 1_000, activeElapsed: 30)
        guard case .some(.split(_, let duration, _)) = cues.first else {
            Issue.record("Expected split after sparse sensor update")
            return
        }
        #expect(duration == 30)
        #expect(cues.count == 1)
        #expect(tracker.processProgress(distanceMeters: 1_005, activeElapsed: 40).isEmpty)
    }

    @Test("Target alert requires warmup and ten sustained seconds")
    func targetAlert() {
        var tracker = RunningFeedbackTracker(settings: .init(paceAlertsEnabled: true))
        for second in stride(from: 10.0, through: 30, by: 10) {
            #expect(tracker.processProgress(distanceMeters: second * 5, activeElapsed: second).isEmpty)
        }
        #expect(tracker.processProgress(distanceMeters: 200, activeElapsed: 40) == [.tooFast])
        for second in stride(from: 50.0, through: 80, by: 10) {
            #expect(tracker.processProgress(distanceMeters: 200 + (second - 40) * 0.5,
                                            activeElapsed: second).isEmpty)
        }
    }

    @Test("A split does not consume a pace alert on the same sample")
    func splitPriority() {
        var tracker = RunningFeedbackTracker(settings: .init(
            distanceIntervalMeters: 500, paceAlertsEnabled: true
        ))
        for second in stride(from: 10.0, through: 30, by: 10) {
            #expect(tracker.processProgress(distanceMeters: second * 15, activeElapsed: second).isEmpty)
        }
        let split = tracker.processProgress(distanceMeters: 600, activeElapsed: 40)
        #expect(split.count == 1)
        #expect(tracker.processProgress(distanceMeters: 750, activeElapsed: 50) == [.tooFast])
    }

    @Test("Opposite pace warning can follow the shared cooldown without crossing the inner band")
    func oppositeDirectionAfterCooldown() {
        var tracker = RunningFeedbackTracker(settings: .init(paceAlertsEnabled: true))
        for second in stride(from: 10.0, through: 40, by: 10) {
            _ = tracker.processProgress(distanceMeters: second * 5, activeElapsed: second)
        }
        for second in stride(from: 50.0, through: 90, by: 10) {
            #expect(tracker.processProgress(distanceMeters: 200 + (second - 40) * 0.5,
                                            activeElapsed: second).isEmpty)
        }
        #expect(tracker.processProgress(distanceMeters: 230, activeElapsed: 100) == [.tooSlow])
    }

    @Test("Pace alert rearms only after returning near target and respects cooldown")
    func paceRearm() {
        var tracker = RunningFeedbackTracker(settings: .init(paceAlertsEnabled: true))
        for second in stride(from: 10.0, through: 40, by: 10) {
            _ = tracker.processProgress(distanceMeters: second * 5, activeElapsed: second)
        }
        // A faster-to-slower swing alone never creates an opposite-direction alert.
        for second in stride(from: 50.0, through: 80, by: 10) {
            #expect(tracker.processProgress(distanceMeters: 200 + (second - 40) * 0.5,
                                            activeElapsed: second).isEmpty)
        }
        for (second, distance) in [(90.0, 248.0), (100, 276), (110, 304), (120, 332)] {
            _ = tracker.processProgress(distanceMeters: distance, activeElapsed: second)
        }
        for (second, distance) in [(130.0, 382.0), (140, 432), (150, 482), (160, 532)] {
            let cues = tracker.processProgress(distanceMeters: distance, activeElapsed: second)
            if second == 160 { #expect(cues == [.tooFast]) }
        }
    }
}
