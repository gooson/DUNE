import Foundation

protocol TrainingReadinessCalculating: Sendable {
    func execute(input: CalculateTrainingReadinessUseCase.Input) -> TrainingReadiness?
}

/// Calculates Training Readiness Score (0-100) from HRV, RHR, sleep, and muscle fatigue.
///
/// Formula: HRV(30%) + RHR(20%) + Sleep(25%) + Fatigue(15%) + Trend(10%)
/// Each component is normalized to 0-100 against a personal 60-day baseline.
/// Reference: Whoop Recovery, Garmin Training Readiness, Oura Readiness Score.
struct CalculateTrainingReadinessUseCase: TrainingReadinessCalculating, Sendable {

    let minimumBaselineDays = 7

    struct Input: Sendable {
        let hrvSamples: [HRVSample]
        let todayRHR: Double?
        let rhrBaseline: [Double]
        let sleepDurationMinutes: Double?
        let deepSleepRatio: Double?
        let remSleepRatio: Double?
        let fatigueStates: [MuscleFatigueState]
    }

    // MARK: - Weights

    private let hrvWeight = 0.30
    private let rhrWeight = 0.20
    private let sleepWeight = 0.25
    private let fatigueWeight = 0.15
    private let trendWeight = 0.10

    // MARK: - Constants

    private let baselineCenter = 50.0
    private let zScaleMultiplier = 15.0
    private let minimumStdDev = 0.05

    func execute(input: Input) -> TrainingReadiness? {
        let dailyAverages = computeDailyAverages(from: input.hrvSamples)
        let hrvComponent = computeHRVScore(dailyAverages: dailyAverages)
        let rhrComponent = computeRHRScore(today: input.todayRHR, baseline: input.rhrBaseline)
        let sleepComponent = computeSleepScore(
            durationMinutes: input.sleepDurationMinutes,
            deepSleepRatio: input.deepSleepRatio,
            remSleepRatio: input.remSleepRatio
        )
        let fatigueComponent = computeFatigueScore(states: input.fatigueStates)
        let trendComponent = computeTrendBonus(dailyAverages: dailyAverages)

        let isCalibrating = input.hrvSamples.isEmpty
            || dailyAverages.count < minimumBaselineDays

        let rawScore = Double(hrvComponent) * hrvWeight
            + Double(rhrComponent) * rhrWeight
            + Double(sleepComponent) * sleepWeight
            + Double(fatigueComponent) * fatigueWeight
            + Double(trendComponent) * trendWeight

        guard rawScore.isFinite, !rawScore.isNaN else { return nil }

        let clamped = Int(max(0, min(100, rawScore)).rounded())
        let components = TrainingReadiness.Components(
            hrvScore: hrvComponent,
            rhrScore: rhrComponent,
            sleepScore: sleepComponent,
            fatigueScore: fatigueComponent,
            trendBonus: trendComponent
        )
        return TrainingReadiness(score: clamped, components: components, isCalibrating: isCalibrating)
    }

    // MARK: - HRV Score (30%)

    /// Normalizes today's HRV against personal baseline using ln-domain z-score.
    private func computeHRVScore(dailyAverages: [(date: Date, value: Double)]) -> Int {
        guard dailyAverages.count >= minimumBaselineDays,
              let todayAvg = dailyAverages.first,
              todayAvg.value > 0 else {
            return 50  // Neutral fallback
        }

        let lnValues = dailyAverages.compactMap { $0.value > 0 ? log($0.value) : nil }
        guard lnValues.count >= minimumBaselineDays else { return 50 }

        let mean = lnValues.reduce(0, +) / Double(lnValues.count)
        let variance = lnValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(lnValues.count)
        guard variance.isFinite, !variance.isNaN else { return 50 }

        let stdDev = sqrt(variance)
        let normalRange = Swift.max(stdDev, minimumStdDev)
        let todayLn = log(todayAvg.value)
        let zScore = (todayLn - mean) / normalRange
        guard zScore.isFinite, !zScore.isNaN else { return 50 }

        let raw = baselineCenter + zScore * zScaleMultiplier
        return Int(max(0, min(100, raw)).rounded())
    }

    // MARK: - RHR Score (20%)

    /// Lower RHR relative to baseline = better score.
    private func computeRHRScore(today: Double?, baseline: [Double]) -> Int {
        guard let todayRHR = today,
              todayRHR > 0, todayRHR.isFinite,
              todayRHR >= 20, todayRHR <= 300 else {
            return 50
        }

        guard !baseline.isEmpty else { return 50 }

        let validBaseline = baseline.filter { $0 > 0 && $0.isFinite && $0 >= 20 && $0 <= 300 }
        guard !validBaseline.isEmpty else { return 50 }

        let mean = validBaseline.reduce(0, +) / Double(validBaseline.count)
        let variance = validBaseline.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(validBaseline.count)
        guard variance.isFinite, !variance.isNaN else { return 50 }

        let stdDev = sqrt(variance)
        let normalRange = Swift.max(stdDev, 1.0)  // RHR has tighter range than HRV

        // Invert: lower RHR = higher score
        let zScore = (mean - todayRHR) / normalRange
        guard zScore.isFinite, !zScore.isNaN else { return 50 }

        let raw = baselineCenter + zScore * zScaleMultiplier
        return Int(max(0, min(100, raw)).rounded())
    }

    // MARK: - Sleep Score (25%)

    /// Score based on sleep duration and quality ratios.
    private func computeSleepScore(
        durationMinutes: Double?,
        deepSleepRatio: Double?,
        remSleepRatio: Double?
    ) -> Int {
        guard let minutes = durationMinutes,
              minutes.isFinite, minutes >= 0, minutes <= 1440 else {
            return 50
        }

        let hours = minutes / 60.0
        let targetHours = 7.5

        // Duration score: linear interpolation capped at target
        let durationFraction = Swift.min(hours / targetHours, 1.3)
        var raw = durationFraction * 70.0  // Max 91 from duration alone

        // Quality bonuses from sleep stages
        if let deep = deepSleepRatio, deep.isFinite, deep >= 0, deep <= 1.0 {
            if deep >= 0.20 { raw += 5 }
            else if deep < 0.10 { raw -= 5 }
        }

        if let rem = remSleepRatio, rem.isFinite, rem >= 0, rem <= 1.0 {
            if rem >= 0.20 { raw += 5 }
            else if rem < 0.10 { raw -= 5 }
        }

        return Int(max(0, min(100, raw)).rounded())
    }

    // MARK: - Fatigue Score (15%)

    /// Lower aggregate fatigue = higher score.
    /// Weights muscles by recency: 24h=1.0, 48h=0.7, 72h=0.4, older=0.1.
    private func computeFatigueScore(states: [MuscleFatigueState]) -> Int {
        guard !states.isEmpty else { return 80 }  // No data = mostly recovered

        let now = Date()
        var weightedSum = 0.0
        var totalWeight = 0.0

        for state in states {
            let fatigueValue = Double(state.fatigueLevel.rawValue)
            let hoursSinceTraining: Double
            if let lastTrained = state.lastTrainedDate {
                hoursSinceTraining = now.timeIntervalSince(lastTrained) / 3600.0
            } else {
                hoursSinceTraining = 168  // 7 days default = fully recovered
            }

            let recencyWeight: Double
            switch hoursSinceTraining {
            case ..<24:    recencyWeight = 1.0
            case 24..<48:  recencyWeight = 0.7
            case 48..<72:  recencyWeight = 0.4
            default:       recencyWeight = 0.1
            }

            weightedSum += fatigueValue * recencyWeight
            totalWeight += recencyWeight
        }

        guard totalWeight > 0 else { return 80 }

        let avgFatigue = weightedSum / totalWeight
        // fatigueLevel ranges 0-10; map to 0-100 score (inverted)
        let raw = 100.0 - (avgFatigue * 10.0)
        return Int(max(0, min(100, raw)).rounded())
    }

    // MARK: - Trend Bonus (10%)

    /// Positive trend in recent HRV daily averages = bonus.
    private func computeTrendBonus(dailyAverages: [(date: Date, value: Double)]) -> Int {
        guard dailyAverages.count >= 3 else { return 50 }

        let recent = Array(dailyAverages.prefix(7).map(\.value))
        guard recent.count >= 3 else { return 50 }

        // Simple linear regression slope
        let n = Double(recent.count)
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for (i, value) in recent.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += value
            sumXY += x * value
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0, denominator.isFinite else { return 50 }

        let slope = (n * sumXY - sumX * sumY) / denominator
        guard slope.isFinite, !slope.isNaN else { return 50 }

        // Normalize slope: positive = improving
        let meanHRV = sumY / n
        guard meanHRV > 0 else { return 50 }

        let normalizedSlope = slope / meanHRV * 100  // Percent change per day
        let raw = baselineCenter + normalizedSlope * 10.0
        return Int(max(0, min(100, raw)).rounded())
    }

    // MARK: - Helpers

    private func computeDailyAverages(from samples: [HRVSample]) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }
        return grouped.compactMap { date, samples in
            let valid = samples.filter { $0.value > 0 && $0.value <= 500 && $0.value.isFinite }
            guard !valid.isEmpty else { return nil }
            let avg = valid.map(\.value).reduce(0, +) / Double(valid.count)
            return (date: date, value: avg)
        }
        .sorted { $0.date > $1.date }
    }
}
