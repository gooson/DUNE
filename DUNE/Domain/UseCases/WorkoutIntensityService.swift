import Foundation

// MARK: - Input Types

/// A single workout session's data for intensity calculation.
struct IntensitySessionInput: Sendable {
    let date: Date
    let exerciseType: ExerciseInputType
    let sets: [IntensitySetInput]
    /// User-rated perceived exertion (1–10), or nil if skipped.
    let rpe: Int?
}

/// A single set's data for intensity calculation.
struct IntensitySetInput: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
    /// User-provided intensity (1–10) for durationIntensity exercises.
    let manualIntensity: Int?
    let setType: SetType
}

// MARK: - Service

/// Computes auto workout intensity by combining multiple signals relative to history.
///
/// Signal weights:
/// - Primary signal (1RM%, percentile, etc.): 60%
/// - Volume/duration signal: 30%
/// - RPE signal: 10%
///
/// Falls back gracefully when signals are unavailable.
struct WorkoutIntensityService: Sendable {

    // MARK: - Validation Constants

    private enum Limits {
        static let weightRange: ClosedRange<Double> = 0.01...500
        static let repsRange: ClosedRange<Int> = 1...1000
        static let durationRange: ClosedRange<TimeInterval> = 0.01...28_800
        static let distanceRange: ClosedRange<Double> = 0.001...500_000
        static let rpeRange: ClosedRange<Int> = 1...10
        static let manualIntensityRange: ClosedRange<Int> = 1...10
        /// Minimum history sessions required for percentile calculation.
        static let minimumHistorySessions = 2
    }

    private enum Weights {
        static let primary: Double = 0.60
        static let volume: Double = 0.30
        static let rpe: Double = 0.10
    }

    // MARK: - Public API

    /// Suggest an effort value (1-10) based on auto-calculated intensity and history calibration.
    ///
    /// - Parameters:
    ///   - autoIntensityRaw: Normalized intensity (0.0-1.0) from `calculateIntensity()`.
    ///   - recentEfforts: User-entered efforts from recent sessions (newest first, up to 5).
    /// - Returns: Effort suggestion with history context, or nil if no data available.
    func suggestEffort(
        autoIntensityRaw: Double?,
        recentEfforts: [Int]
    ) -> EffortSuggestion? {
        let validEfforts = recentEfforts.prefix(5).filter { Limits.rpeRange.contains($0) }

        guard let raw = autoIntensityRaw, raw.isFinite, (0...1).contains(raw) else {
            // No auto intensity — return history-based suggestion if available
            guard let last = validEfforts.first else { return nil }
            let avg = Double(validEfforts.reduce(0, +)) / Double(validEfforts.count)
            return EffortSuggestion(
                suggestedEffort: last,
                category: EffortCategory(effort: last),
                lastEffort: last,
                averageEffort: avg.isFinite ? avg : nil
            )
        }

        // Convert 0.0-1.0 → 1-10
        var suggested = Int(round(raw * 9.0)) + 1
        suggested = Swift.max(1, Swift.min(10, suggested))

        // History calibration: if user consistently rates differently, adjust
        if validEfforts.count >= 3 {
            let userAvg = Double(validEfforts.reduce(0, +)) / Double(validEfforts.count)
            guard userAvg.isFinite else {
                return buildSuggestion(suggested, validEfforts: Array(validEfforts))
            }
            let bias = userAvg - Double(suggested)
            if abs(bias) >= 1.0 {
                suggested = Swift.max(1, Swift.min(10, suggested + Int(round(bias * 0.5))))
            }
        }

        return buildSuggestion(suggested, validEfforts: Array(validEfforts))
    }

    private func buildSuggestion(_ effort: Int, validEfforts: [Int]) -> EffortSuggestion {
        let avg: Double? = validEfforts.isEmpty ? nil : {
            let sum = Double(validEfforts.reduce(0, +)) / Double(validEfforts.count)
            return sum.isFinite ? sum : nil
        }()
        return EffortSuggestion(
            suggestedEffort: effort,
            category: EffortCategory(effort: effort),
            lastEffort: validEfforts.first,
            averageEffort: avg
        )
    }

    /// Calculate intensity for the current session relative to historical sessions.
    ///
    /// - Parameters:
    ///   - current: The session just completed.
    ///   - history: Past sessions for the same exercise, sorted oldest-first.
    ///   - estimated1RM: Best estimated 1RM from OneRMEstimationService (strength only).
    /// - Returns: Intensity result, or nil if insufficient data.
    func calculateIntensity(
        current: IntensitySessionInput,
        history: [IntensitySessionInput],
        estimated1RM: Double? = nil
    ) -> WorkoutIntensityResult? {
        let signals: (primary: Double?, volume: Double?, method: IntensityMethod)?
        switch current.exerciseType {
        case .setsRepsWeight:
            signals = strengthSignals(current: current, history: history, estimated1RM: estimated1RM)
        case .setsReps:
            signals = bodyweightSignals(current: current, history: history)
        case .durationDistance:
            signals = cardioSignals(current: current, history: history)
        case .durationIntensity:
            signals = flexibilitySignals(current: current, history: history)
        case .roundsBased:
            signals = roundsSignals(current: current, history: history)
        }
        return buildResult(signals: signals, current: current)
    }

    // MARK: - Signal Extraction per Exercise Type

    private func strengthSignals(
        current: IntensitySessionInput,
        history: [IntensitySessionInput],
        estimated1RM: Double?
    ) -> (primary: Double?, volume: Double?, method: IntensityMethod)? {
        let workingSets = validWorkingSets(from: current.sets)
        let weights = workingSets.compactMap(\.weight).filter { Limits.weightRange.contains($0) }
        guard !weights.isEmpty else { return nil }

        var primarySignal: Double?
        if let oneRM = estimated1RM, oneRM > 0 {
            let avgWeight = weights.reduce(0, +) / Double(weights.count)
            guard avgWeight.isFinite else { return nil }
            primarySignal = clamp01(avgWeight / oneRM)
        }

        let volumeSignal = volumeRatio(current: current, history: history)
        return (primarySignal, volumeSignal, primarySignal != nil ? .oneRMBased : .repsPercentile)
    }

    private func bodyweightSignals(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> (primary: Double?, volume: Double?, method: IntensityMethod)? {
        let currentReps = totalValidReps(from: current.sets)
        guard currentReps > 0 else { return nil }

        let historyReps = history.map { totalValidReps(from: $0.sets) }.filter { $0 > 0 }
        let primarySignal = percentile(value: Double(currentReps), in: historyReps.map(Double.init))

        let volumeSignal: Double? = {
            guard !historyReps.isEmpty else { return nil }
            let avg = Double(historyReps.reduce(0, +)) / Double(historyReps.count)
            guard avg > 0, avg.isFinite else { return nil }
            return clamp01(Double(currentReps) / avg)
        }()

        return (primarySignal, volumeSignal, .repsPercentile)
    }

    private func cardioSignals(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> (primary: Double?, volume: Double?, method: IntensityMethod)? {
        let currentPace = sessionPace(from: current.sets)
        guard let currentPace, currentPace > 0, currentPace.isFinite else { return nil }

        let historyPaces = history.compactMap { sessionPace(from: $0.sets) }
            .filter { $0 > 0 && $0.isFinite }
        let primarySignal: Double? = {
            guard let p = percentile(value: currentPace, in: historyPaces) else { return nil }
            return clamp01(1.0 - p) // Invert: lower pace (faster) = higher intensity
        }()

        let volumeSignal = durationVolumeSignal(current: current, history: history)
        return (primarySignal, volumeSignal, .pacePercentile)
    }

    private func flexibilitySignals(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> (primary: Double?, volume: Double?, method: IntensityMethod)? {
        let intensities = current.sets
            .compactMap(\.manualIntensity)
            .filter { Limits.manualIntensityRange.contains($0) }
        let primarySignal: Double? = {
            guard !intensities.isEmpty else { return nil }
            let avg = Double(intensities.reduce(0, +)) / Double(intensities.count)
            guard avg.isFinite else { return nil }
            return clamp01(avg / 10.0)
        }()

        let volumeSignal = durationVolumeSignal(current: current, history: history)
        return (primarySignal, volumeSignal, .manualIntensity)
    }

    private func roundsSignals(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> (primary: Double?, volume: Double?, method: IntensityMethod)? {
        let currentCount = current.sets.filter { validSet($0) }.count
        guard currentCount > 0 else { return nil }

        let historyCounts = history.map { $0.sets.filter { self.validSet($0) }.count }.filter { $0 > 0 }
        let primarySignal = percentile(value: Double(currentCount), in: historyCounts.map(Double.init))

        let volumeSignal = durationVolumeSignal(current: current, history: history)
        return (primarySignal, volumeSignal, .roundsPercentile)
    }

    // MARK: - Common Result Builder (Correction #148)

    /// Combines extracted signals into a result, with RPE fallback when both primary and volume are nil.
    private func buildResult(
        signals: (primary: Double?, volume: Double?, method: IntensityMethod)?,
        current: IntensitySessionInput
    ) -> WorkoutIntensityResult? {
        guard let signals else { return rpeFallback(current: current) }

        let rpeSignal = normalizedRPE(current.rpe)

        if signals.primary == nil && signals.volume == nil {
            return rpeFallback(current: current)
        }

        let score = combineSignals(primary: signals.primary, volume: signals.volume, rpe: rpeSignal)
        guard let score else { return rpeFallback(current: current) }

        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: signals.primary,
                volumeSignal: signals.volume,
                rpeSignal: rpeSignal,
                method: signals.method
            )
        )
    }

    // MARK: - Signal Combination

    /// Weighted combination of available signals. Redistributes weight of missing signals.
    private func combineSignals(primary: Double?, volume: Double?, rpe: Double?) -> Double? {
        var totalWeight = 0.0
        var weightedSum = 0.0

        if let p = primary {
            weightedSum += p * Weights.primary
            totalWeight += Weights.primary
        }
        if let v = volume {
            weightedSum += v * Weights.volume
            totalWeight += Weights.volume
        }
        if let r = rpe {
            weightedSum += r * Weights.rpe
            totalWeight += Weights.rpe
        }

        guard totalWeight > 0 else { return nil }
        let result = weightedSum / totalWeight
        guard result.isFinite else { return nil }
        return clamp01(result)
    }

    // MARK: - RPE Fallback

    private func rpeFallback(current: IntensitySessionInput) -> WorkoutIntensityResult? {
        guard let rpe = current.rpe, Limits.rpeRange.contains(rpe) else { return nil }
        let score = clamp01(Double(rpe) / 10.0)
        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: nil,
                volumeSignal: nil,
                rpeSignal: score,
                method: .rpeOnly
            )
        )
    }

    // MARK: - Helpers

    private func validWorkingSets(from sets: [IntensitySetInput]) -> [IntensitySetInput] {
        sets.filter { $0.setType == .working || $0.setType == .failure || $0.setType == .drop }
    }

    private func validSet(_ set: IntensitySetInput) -> Bool {
        if let w = set.weight, Limits.weightRange.contains(w) { return true }
        if let r = set.reps, Limits.repsRange.contains(r) { return true }
        if let d = set.duration, Limits.durationRange.contains(d) { return true }
        if let dist = set.distance, Limits.distanceRange.contains(dist) { return true }
        return false
    }

    private func totalValidReps(from sets: [IntensitySetInput]) -> Int {
        sets.compactMap(\.reps)
            .filter { Limits.repsRange.contains($0) }
            .reduce(0, +)
    }

    private func totalValidDuration(from sets: [IntensitySetInput]) -> TimeInterval {
        sets.compactMap(\.duration)
            .filter { Limits.durationRange.contains($0) }
            .reduce(0, +)
    }

    /// Compute session pace as total duration / total distance (seconds per meter).
    private func sessionPace(from sets: [IntensitySetInput]) -> Double? {
        let duration = totalValidDuration(from: sets)
        let distance = sets.compactMap(\.distance)
            .filter { Limits.distanceRange.contains($0) }
            .reduce(0, +)
        guard duration > 0, distance > 0 else { return nil }
        let pace = duration / distance
        guard pace.isFinite else { return nil }
        return pace
    }

    /// Volume for strength exercises: sum of (weight x reps) for working sets.
    private func sessionVolume(from sets: [IntensitySetInput]) -> Double {
        var total = 0.0
        for set in validWorkingSets(from: sets) {
            guard let w = set.weight, Limits.weightRange.contains(w),
                  let r = set.reps, Limits.repsRange.contains(r) else { continue }
            let vol = w * Double(r)
            guard vol.isFinite, vol <= 50_000 else { continue } // Correction #85
            total += vol
        }
        guard total.isFinite, total <= 500_000 else { return 0 } // session upper bound
        return total
    }

    /// Strength volume ratio: current session volume / history average volume.
    private func volumeRatio(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> Double? {
        let currentVol = sessionVolume(from: current.sets)
        guard currentVol > 0 else { return nil }

        let historyVols = history.map { sessionVolume(from: $0.sets) }.filter { $0 > 0 }
        guard !historyVols.isEmpty else { return nil }

        let histSum = historyVols.reduce(0, +)
        guard histSum.isFinite else { return nil }
        let avg = histSum / Double(historyVols.count)
        guard avg > 0, avg.isFinite else { return nil }

        let ratio = currentVol / avg
        guard ratio.isFinite else { return nil }
        return clamp01(ratio)
    }

    /// Duration-based volume signal: current total duration / history average duration.
    /// Shared by cardio, flexibility, and rounds-based exercise types.
    private func durationVolumeSignal(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> Double? {
        let currentDuration = totalValidDuration(from: current.sets)
        guard currentDuration > 0 else { return nil }

        let historyDurations = history.map { totalValidDuration(from: $0.sets) }.filter { $0 > 0 }
        guard !historyDurations.isEmpty else { return nil }

        let histSum = historyDurations.reduce(0, +)
        guard histSum.isFinite else { return nil }
        let avg = histSum / Double(historyDurations.count)
        guard avg > 0, avg.isFinite else { return nil }

        let ratio = currentDuration / avg
        guard ratio.isFinite else { return nil }
        return clamp01(ratio)
    }

    /// Percentile rank of value within history (0.0 = lowest, 1.0 = highest).
    /// Returns nil if fewer than `minimumHistorySessions` valid values.
    private func percentile(value: Double, in values: [Double]) -> Double? {
        let valid = values.filter { $0.isFinite }
        guard valid.count >= Limits.minimumHistorySessions else { return nil }
        let belowCount = valid.filter { $0 < value }.count
        let result = Double(belowCount) / Double(valid.count)
        guard result.isFinite else { return nil }
        return clamp01(result)
    }

    private func normalizedRPE(_ rpe: Int?) -> Double? {
        guard let rpe, Limits.rpeRange.contains(rpe) else { return nil }
        return Double(rpe) / 10.0
    }

    private func clamp01(_ value: Double) -> Double {
        Swift.max(0, Swift.min(1, value))
    }
}
