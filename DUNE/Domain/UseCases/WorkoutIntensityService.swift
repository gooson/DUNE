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
    }

    private enum Weights {
        static let primary: Double = 0.60
        static let volume: Double = 0.30
        static let rpe: Double = 0.10
    }

    // MARK: - Public API

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
        switch current.exerciseType {
        case .setsRepsWeight:
            return strengthIntensity(current: current, history: history, estimated1RM: estimated1RM)
        case .setsReps:
            return bodyweightIntensity(current: current, history: history)
        case .durationDistance:
            return cardioIntensity(current: current, history: history)
        case .durationIntensity:
            return flexibilityIntensity(current: current, history: history)
        case .roundsBased:
            return roundsIntensity(current: current, history: history)
        }
    }

    // MARK: - Strength (setsRepsWeight)

    private func strengthIntensity(
        current: IntensitySessionInput,
        history: [IntensitySessionInput],
        estimated1RM: Double?
    ) -> WorkoutIntensityResult? {
        let workingSets = validWorkingSets(from: current.sets)
        let weights = workingSets.compactMap(\.weight).filter { Limits.weightRange.contains($0) }
        guard !weights.isEmpty else { return rpeFallback(current: current) }

        // Primary: average working weight as % of 1RM
        var primarySignal: Double?
        if let oneRM = estimated1RM, oneRM > 0 {
            let avgWeight = weights.reduce(0, +) / Double(weights.count)
            guard avgWeight.isFinite else { return rpeFallback(current: current) }
            let ratio = avgWeight / oneRM
            primarySignal = clamp01(ratio)
        }

        // Volume: session volume vs history average
        let volumeSignal = volumeRatio(current: current, history: history)

        // RPE
        let rpeSignal = normalizedRPE(current.rpe)

        // If no primary signal and no history, try RPE fallback
        if primarySignal == nil && volumeSignal == nil {
            return rpeFallback(current: current)
        }

        let score = combineSignals(primary: primarySignal, volume: volumeSignal, rpe: rpeSignal)
        guard let score else { return rpeFallback(current: current) }

        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: primarySignal,
                volumeSignal: volumeSignal,
                rpeSignal: rpeSignal,
                method: primarySignal != nil ? .oneRMBased : .repsPercentile
            )
        )
    }

    // MARK: - Bodyweight (setsReps)

    private func bodyweightIntensity(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> WorkoutIntensityResult? {
        let currentReps = totalValidReps(from: current.sets)
        guard currentReps > 0 else { return rpeFallback(current: current) }

        // Primary: reps percentile in history
        let historyReps = history.map { totalValidReps(from: $0.sets) }.filter { $0 > 0 }
        let primarySignal: Double? = percentile(value: Double(currentReps), in: historyReps.map(Double.init))

        // Volume: total reps vs avg
        let volumeSignal: Double? = {
            guard !historyReps.isEmpty else { return nil }
            let avg = Double(historyReps.reduce(0, +)) / Double(historyReps.count)
            guard avg > 0, avg.isFinite else { return nil }
            return clamp01(Double(currentReps) / avg)
        }()

        let rpeSignal = normalizedRPE(current.rpe)

        if primarySignal == nil && volumeSignal == nil {
            return rpeFallback(current: current)
        }

        let score = combineSignals(primary: primarySignal, volume: volumeSignal, rpe: rpeSignal)
        guard let score else { return rpeFallback(current: current) }

        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: primarySignal,
                volumeSignal: volumeSignal,
                rpeSignal: rpeSignal,
                method: .repsPercentile
            )
        )
    }

    // MARK: - Cardio (durationDistance)

    private func cardioIntensity(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> WorkoutIntensityResult? {
        // Pace = duration / distance (lower = faster = harder)
        let currentPace = sessionPace(from: current.sets)
        guard let currentPace, currentPace > 0, currentPace.isFinite else {
            return rpeFallback(current: current)
        }

        // Primary: inverted pace percentile (faster = higher intensity)
        let historyPaces = history.compactMap { sessionPace(from: $0.sets) }
            .filter { $0 > 0 && $0.isFinite }
        let primarySignal: Double? = {
            guard let p = percentile(value: currentPace, in: historyPaces) else { return nil }
            return clamp01(1.0 - p) // Invert: lower pace (faster) = higher intensity
        }()

        // Volume: duration vs avg
        let currentDuration = totalValidDuration(from: current.sets)
        let volumeSignal: Double? = {
            let historyDurations = history.map { totalValidDuration(from: $0.sets) }.filter { $0 > 0 }
            guard !historyDurations.isEmpty else { return nil }
            let avg = historyDurations.reduce(0, +) / Double(historyDurations.count)
            guard avg > 0, avg.isFinite, currentDuration > 0 else { return nil }
            return clamp01(currentDuration / avg)
        }()

        let rpeSignal = normalizedRPE(current.rpe)

        if primarySignal == nil && volumeSignal == nil {
            return rpeFallback(current: current)
        }

        let score = combineSignals(primary: primarySignal, volume: volumeSignal, rpe: rpeSignal)
        guard let score else { return rpeFallback(current: current) }

        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: primarySignal,
                volumeSignal: volumeSignal,
                rpeSignal: rpeSignal,
                method: .pacePercentile
            )
        )
    }

    // MARK: - Flexibility (durationIntensity)

    private func flexibilityIntensity(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> WorkoutIntensityResult? {
        // Primary: average manual intensity across sets
        let intensities = current.sets
            .compactMap(\.manualIntensity)
            .filter { Limits.manualIntensityRange.contains($0) }
        let primarySignal: Double? = {
            guard !intensities.isEmpty else { return nil }
            let avg = Double(intensities.reduce(0, +)) / Double(intensities.count)
            guard avg.isFinite else { return nil }
            return clamp01(avg / 10.0)
        }()

        // Volume: duration vs avg
        let currentDuration = totalValidDuration(from: current.sets)
        let volumeSignal: Double? = {
            let historyDurations = history.map { totalValidDuration(from: $0.sets) }.filter { $0 > 0 }
            guard !historyDurations.isEmpty else { return nil }
            let avg = historyDurations.reduce(0, +) / Double(historyDurations.count)
            guard avg > 0, avg.isFinite, currentDuration > 0 else { return nil }
            return clamp01(currentDuration / avg)
        }()

        let rpeSignal = normalizedRPE(current.rpe)

        if primarySignal == nil && volumeSignal == nil {
            return rpeFallback(current: current)
        }

        let score = combineSignals(primary: primarySignal, volume: volumeSignal, rpe: rpeSignal)
        guard let score else { return rpeFallback(current: current) }

        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: primarySignal,
                volumeSignal: volumeSignal,
                rpeSignal: rpeSignal,
                method: .manualIntensity
            )
        )
    }

    // MARK: - Rounds-Based (HIIT)

    private func roundsIntensity(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> WorkoutIntensityResult? {
        // Primary: completed set count percentile
        let currentCount = current.sets.filter { validSet($0) }.count
        guard currentCount > 0 else { return rpeFallback(current: current) }

        let historyCounts = history.map { $0.sets.filter { self.validSet($0) }.count }.filter { $0 > 0 }
        let primarySignal = percentile(value: Double(currentCount), in: historyCounts.map(Double.init))

        // Volume: duration vs avg
        let currentDuration = totalValidDuration(from: current.sets)
        let volumeSignal: Double? = {
            let historyDurations = history.map { totalValidDuration(from: $0.sets) }.filter { $0 > 0 }
            guard !historyDurations.isEmpty else { return nil }
            let avg = historyDurations.reduce(0, +) / Double(historyDurations.count)
            guard avg > 0, avg.isFinite, currentDuration > 0 else { return nil }
            return clamp01(currentDuration / avg)
        }()

        let rpeSignal = normalizedRPE(current.rpe)

        if primarySignal == nil && volumeSignal == nil {
            return rpeFallback(current: current)
        }

        let score = combineSignals(primary: primarySignal, volume: volumeSignal, rpe: rpeSignal)
        guard let score else { return rpeFallback(current: current) }

        return WorkoutIntensityResult(
            level: WorkoutIntensityLevel(rawScore: score),
            rawScore: score,
            detail: WorkoutIntensityDetail(
                primarySignal: primarySignal,
                volumeSignal: volumeSignal,
                rpeSignal: rpeSignal,
                method: .repsPercentile
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

    /// Volume for strength exercises: sum of (weight × reps) for working sets.
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

    private func volumeRatio(
        current: IntensitySessionInput,
        history: [IntensitySessionInput]
    ) -> Double? {
        let currentVol = sessionVolume(from: current.sets)
        guard currentVol > 0 else { return nil }

        let historyVols = history.map { sessionVolume(from: $0.sets) }.filter { $0 > 0 }
        guard !historyVols.isEmpty else { return nil }

        let avg = historyVols.reduce(0, +) / Double(historyVols.count)
        guard avg > 0, avg.isFinite else { return nil }

        let ratio = currentVol / avg
        guard ratio.isFinite else { return nil }
        return clamp01(ratio)
    }

    /// Percentile rank of value within sorted array (0.0 = lowest, 1.0 = highest).
    private func percentile(value: Double, in values: [Double]) -> Double? {
        let valid = values.filter { $0.isFinite }
        guard !valid.isEmpty else { return nil }
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
