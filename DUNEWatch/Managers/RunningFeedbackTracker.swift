import Foundation

/// Converts active workout samples into complete distance splits and restrained pace alerts.
struct RunningFeedbackTracker {
    enum Cue: Equatable {
        case split(distanceMeters: Int, durationSeconds: Double, paceSecondsPerKm: Double)
        case tooFast
        case tooSlow
    }

    private struct Sample {
        let distance: Double
        let elapsed: Double
    }

    private(set) var settings: RunningFeedbackSettings
    private var lastSample: Sample?
    private var nextBoundary: Double = 0
    private var splitStartElapsed: Double?
    private var recentSamples: [Sample] = []
    private var alertWarmupStart: Double = 0
    private var candidate: Cue?
    private var candidateStart: Double?
    private var lastAlertElapsed: Double?
    private var lastAlertDirection: Cue?
    private var alertArmed = true
    private var isSuspended = false

    init(settings: RunningFeedbackSettings = .init()) {
        self.settings = settings.normalized
        resetProgress()
    }

    mutating func updateSettings(_ settings: RunningFeedbackSettings) {
        let normalized = settings.normalized
        let intervalChanged = self.settings.distanceIntervalMeters != normalized.distanceIntervalMeters
        let alertChanged = self.settings.paceAlertsEnabled != normalized.paceAlertsEnabled
            || self.settings.targetPaceSecondsPerKm != normalized.targetPaceSecondsPerKm
            || self.settings.paceToleranceSecondsPerKm != normalized.paceToleranceSecondsPerKm
        self.settings = normalized
        if intervalChanged, let sample = lastSample {
            rebaseSplit(at: sample)
        }
        if alertChanged, let sample = lastSample {
            resetAlert(at: sample)
        }
    }

    mutating func resetProgress(distanceMeters: Double = 0, activeElapsed: Double = 0) {
        let sample = validSample(distanceMeters: distanceMeters, activeElapsed: activeElapsed)
            ?? Sample(distance: 0, elapsed: 0)
        lastSample = sample
        isSuspended = false
        rebaseSplit(at: sample)
        resetAlert(at: sample)
    }

    mutating func suspendProgress() {
        isSuspended = true
        recentSamples.removeAll(keepingCapacity: true)
        candidate = nil
        candidateStart = nil
    }

    mutating func restartPaceFeedback() {
        guard let sample = lastSample else { return }
        resetAlert(at: sample)
    }

    mutating func resumeProgress(distanceMeters: Double, activeElapsed: Double) {
        guard let sample = validSample(distanceMeters: distanceMeters, activeElapsed: activeElapsed) else {
            resetProgress()
            return
        }
        if let previous = lastSample,
           sample.distance == previous.distance,
           sample.elapsed >= previous.elapsed {
            lastSample = sample
            isSuspended = false
            resetAlert(at: sample)
        } else {
            resetProgress(distanceMeters: distanceMeters, activeElapsed: activeElapsed)
        }
    }

    mutating func processProgress(distanceMeters: Double, activeElapsed: Double) -> [Cue] {
        guard !isSuspended else { return [] }
        guard let sample = validSample(distanceMeters: distanceMeters, activeElapsed: activeElapsed) else {
            lastSample = nil
            recentSamples.removeAll(keepingCapacity: true)
            candidate = nil
            return []
        }
        guard let previous = lastSample else {
            resetProgress(distanceMeters: distanceMeters, activeElapsed: activeElapsed)
            return []
        }
        guard sample.distance >= previous.distance,
              sample.elapsed >= previous.elapsed,
              !(sample.elapsed == previous.elapsed && sample.distance > previous.distance) else {
            resetProgress(distanceMeters: distanceMeters, activeElapsed: activeElapsed)
            return []
        }
        if sample.distance == previous.distance, sample.elapsed == previous.elapsed { return [] }
        let isStaleForPace = sample.elapsed - previous.elapsed > 15

        lastSample = sample
        var latestSplit: Cue?
        if sample.distance > previous.distance, sample.elapsed > previous.elapsed {
            while nextBoundary <= sample.distance {
                let fraction = (nextBoundary - previous.distance) / (sample.distance - previous.distance)
                let boundaryElapsed = previous.elapsed + fraction * (sample.elapsed - previous.elapsed)
                if let start = splitStartElapsed {
                    let duration = boundaryElapsed - start
                    if duration > 0 {
                        latestSplit = .split(
                            distanceMeters: Int(settings.distanceIntervalMeters),
                            durationSeconds: duration,
                            paceSecondsPerKm: duration * 1_000 / settings.distanceIntervalMeters
                        )
                    }
                }
                splitStartElapsed = boundaryElapsed
                nextBoundary += settings.distanceIntervalMeters
            }
        }

        if isStaleForPace {
            resetAlert(at: sample)
            return latestSplit.map { [$0] } ?? []
        }
        recentSamples.append(sample)
        trimRecentSamples(at: sample.elapsed)
        if let latestSplit { return [latestSplit] }
        let paceCue = evaluatePace(at: sample)
        if let paceCue { return [paceCue] }
        return []
    }

    private mutating func rebaseSplit(at sample: Sample) {
        let interval = settings.distanceIntervalMeters
        nextBoundary = sample.distance + interval
        splitStartElapsed = sample.elapsed
    }

    private mutating func resetAlert(at sample: Sample) {
        recentSamples = [sample]
        alertWarmupStart = sample.elapsed
        candidate = nil
        candidateStart = nil
        lastAlertElapsed = nil
        lastAlertDirection = nil
        alertArmed = true
    }

    private mutating func trimRecentSamples(at elapsed: Double) {
        // Keep one sample before the 30-second edge for a stable rolling window.
        while recentSamples.count > 2, recentSamples[1].elapsed <= elapsed - 30 {
            recentSamples.removeFirst()
        }
    }

    private mutating func evaluatePace(at sample: Sample) -> Cue? {
        guard settings.paceAlertsEnabled,
              sample.elapsed - alertWarmupStart >= 30,
              let oldest = recentSamples.first,
              sample.elapsed - oldest.elapsed >= 10,
              sample.distance > oldest.distance else { return nil }

        let pace = (sample.elapsed - oldest.elapsed) * 1_000 / (sample.distance - oldest.distance)
        let delta = pace - settings.targetPaceSecondsPerKm
        if abs(delta) <= settings.paceToleranceSecondsPerKm / 2 {
            alertArmed = true
            candidate = nil
            candidateStart = nil
            return nil
        }

        let direction: Cue
        if delta < -settings.paceToleranceSecondsPerKm {
            direction = .tooFast
        } else if delta > settings.paceToleranceSecondsPerKm {
            direction = .tooSlow
        } else {
            candidate = nil
            candidateStart = nil
            return nil
        }

        if candidate != direction {
            candidate = direction
            candidateStart = sample.elapsed
            return nil
        }
        guard alertArmed || lastAlertDirection != direction,
              sample.elapsed - (candidateStart ?? sample.elapsed) >= 10,
              lastAlertElapsed.map({ sample.elapsed - $0 >= 60 }) ?? true else { return nil }
        alertArmed = false
        lastAlertElapsed = sample.elapsed
        lastAlertDirection = direction
        candidate = nil
        candidateStart = nil
        return direction
    }

    private func validSample(distanceMeters: Double, activeElapsed: Double) -> Sample? {
        guard distanceMeters.isFinite, activeElapsed.isFinite,
              distanceMeters >= 0, distanceMeters <= 500_000,
              activeElapsed >= 0 else { return nil }
        return Sample(distance: distanceMeters, elapsed: activeElapsed)
    }
}
