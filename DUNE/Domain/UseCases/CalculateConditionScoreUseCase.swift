import Foundation

protocol ConditionScoreCalculating: Sendable {
    func execute(input: CalculateConditionScoreUseCase.Input) -> CalculateConditionScoreUseCase.Output
}

struct CalculateConditionScoreUseCase: ConditionScoreCalculating, Sendable {
    let requiredDays = 7

    /// Number of days to include in the condition score baseline window.
    /// The use case trims incoming HRV and RHR series to this rolling window.
    static let conditionWindowDays = 14

    private let baselineScore = 50.0
    private let zScoreMultiplier = 15.0
    private let minimumStdDev = 0.25
    private let minimumRHRStdDev = 2.0
    private let rhrZScoreMultiplier = 4.0
    private let rhrImpactThreshold = 0.5
    private let maximumRHRAdjustment = 12.0

    /// Physiological RHR bounds (bpm) — values outside are ignored
    private let rhrValidRange = 20.0...300.0
    /// Physiological HRV bounds (ms) — daily averages outside are excluded
    private let hrvValidRange = 0.0...500.0

    struct Input: Sendable {
        struct RHRDailyAverage: Sendable, Hashable {
            let date: Date
            let value: Double
        }

        let hrvSamples: [HRVSample]
        let rhrDailyAverages: [RHRDailyAverage]
        let todayRHR: Double?
        let yesterdayRHR: Double?
        /// Effective RHR for UI display (fallback when todayRHR is nil)
        let displayRHR: Double?
        let displayRHRDate: Date?
        let evaluationDate: Date

        init(
            hrvSamples: [HRVSample],
            rhrDailyAverages: [RHRDailyAverage] = [],
            todayRHR: Double?,
            yesterdayRHR: Double?,
            displayRHR: Double? = nil,
            displayRHRDate: Date? = nil,
            evaluationDate: Date = Date()
        ) {
            self.hrvSamples = hrvSamples
            self.rhrDailyAverages = rhrDailyAverages
            self.todayRHR = todayRHR
            self.yesterdayRHR = yesterdayRHR
            self.displayRHR = displayRHR
            self.displayRHRDate = displayRHRDate
            self.evaluationDate = evaluationDate
        }
    }

    struct Output: Sendable {
        let score: ConditionScore?
        let baselineStatus: BaselineStatus
        let contributions: [ScoreContribution]
    }

    func execute(input: Input) -> Output {
        let dailyAverages = Array(computeDailyAverages(from: input.hrvSamples).prefix(Self.conditionWindowDays))
        let baselineStatus = BaselineStatus(
            daysCollected: dailyAverages.count,
            daysRequired: requiredDays
        )

        guard baselineStatus.isReady,
              let todayAverage = dailyAverages.first else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let validAverages = dailyAverages.filter { $0.value > 0 && hrvValidRange.contains($0.value) }
        guard !validAverages.isEmpty,
              todayAverage.value > 0,
              hrvValidRange.contains(todayAverage.value) else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let lnValues = validAverages.map { log($0.value) }
        let baseline = lnValues.reduce(0, +) / Double(lnValues.count)
        let todayLn = log(todayAverage.value)

        let variance = lnValues.map { ($0 - baseline) * ($0 - baseline) }
            .reduce(0, +) / Double(lnValues.count)

        guard !variance.isNaN && !variance.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let stdDev = sqrt(variance)
        let normalRange = max(stdDev, minimumStdDev)

        let zScore = (todayLn - baseline) / normalRange
        guard !zScore.isNaN && !zScore.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }
        var rawScore = baselineScore + (zScore * zScoreMultiplier)

        var contributions: [ScoreContribution] = []
        let baselineHRV = exp(baseline)

        guard !baselineHRV.isNaN && !baselineHRV.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let todayHRVms = todayAverage.value

        let hrvImpact: ScoreContribution.Impact
        let hrvDetail: String
        if zScore > 0.5 {
            hrvImpact = .positive
            hrvDetail = String(format: "%.0fms — above %.0fms avg", todayHRVms, baselineHRV)
        } else if zScore < -0.5 {
            hrvImpact = .negative
            hrvDetail = String(format: "%.0fms — below %.0fms avg", todayHRVms, baselineHRV)
        } else {
            hrvImpact = .neutral
            hrvDetail = String(format: "%.0fms — near %.0fms avg", todayHRVms, baselineHRV)
        }
        contributions.append(ScoreContribution(factor: .hrv, impact: hrvImpact, detail: hrvDetail))

        let calendar = Calendar.current
        let scoreDate = calendar.startOfDay(for: todayAverage.date)
        let dailyRHR = computeDailyRHR(from: input.rhrDailyAverages)
        let todayRHR = validatedRHR(input.todayRHR) ?? dailyRHR.first(where: {
            calendar.isDate($0.date, inSameDayAs: scoreDate)
        })?.value
        let resolvedYesterdayRHR: Double? = {
            if let inputYesterday = validatedRHR(input.yesterdayRHR) {
                return inputYesterday
            }
            guard let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: scoreDate) else {
                return nil
            }
            return dailyRHR.first(where: {
                calendar.isDate($0.date, inSameDayAs: yesterdayDate)
            })?.value
        }()

        let rhrBaselineSamples = Array(
            dailyRHR
                .filter { $0.date < scoreDate }
                .prefix(Self.conditionWindowDays)
        )
        let rhrBaselineValues = rhrBaselineSamples.map(\.value)
        let baselineRHR = average(rhrBaselineValues)
        let rhrDeltaFromBaseline = todayRHR.flatMap { today in
            baselineRHR.map { today - $0 }
        }

        var rhrAdjustment = 0.0
        if let todayRHR,
           let baselineRHR,
           rhrBaselineValues.count >= requiredDays,
           let rhrDeltaFromBaseline {
            let rhrStdDev = standardDeviation(rhrBaselineValues)
            let effectiveRHRStdDev = max(rhrStdDev, minimumRHRStdDev)
            let rhrZScore = rhrDeltaFromBaseline / effectiveRHRStdDev

            if rhrZScore.isFinite {
                rhrAdjustment = max(
                    -maximumRHRAdjustment,
                    min(maximumRHRAdjustment, -(rhrZScore * rhrZScoreMultiplier))
                )
                rawScore += rhrAdjustment
            }

            let rhrImpact: ScoreContribution.Impact
            if rhrZScore < -rhrImpactThreshold {
                rhrImpact = .positive
            } else if rhrZScore > rhrImpactThreshold {
                rhrImpact = .negative
            } else {
                rhrImpact = .neutral
            }

            let rhrDetail: String
            if abs(rhrDeltaFromBaseline) < 0.5 {
                rhrDetail = String(format: "%.0f bpm — near %.0f bpm baseline", todayRHR, baselineRHR)
            } else {
                let deltaText = rhrDeltaFromBaseline.formattedWithSeparator(
                    fractionDigits: 0,
                    alwaysShowSign: true
                )
                rhrDetail = String(format: "%.0f bpm — %@ vs %.0f bpm baseline", todayRHR, deltaText, baselineRHR)
            }
            contributions.append(ScoreContribution(factor: .rhr, impact: rhrImpact, detail: rhrDetail))
        } else if let todayRHR {
            let detail = String(format: "%.0f bpm — building baseline", todayRHR)
            contributions.append(ScoreContribution(factor: .rhr, impact: .neutral, detail: detail))
        } else if let displayRHR = validatedRHR(input.displayRHR) {
            let detail: String
            if let displayRHRDate = input.displayRHRDate {
                detail = String(
                    format: "%.0f bpm — latest sample %@",
                    displayRHR,
                    Self.Cache.shortDate.string(from: displayRHRDate)
                )
            } else {
                detail = String(format: "%.0f bpm — latest sample", displayRHR)
            }
            contributions.append(ScoreContribution(factor: .rhr, impact: .neutral, detail: detail))
        }

        let timeAdjustment = timeOfDayAdjustment(for: input.evaluationDate)
        rawScore += timeAdjustment

        let clampedScore = Int(max(0, min(100, rawScore)).rounded())

        let detail = ConditionScoreDetail(
            todayHRV: todayHRVms,
            baselineHRV: baselineHRV,
            zScore: zScore,
            stdDev: stdDev,
            effectiveStdDev: normalRange,
            daysInBaseline: validAverages.count,
            todayDate: todayAverage.date,
            rawScore: rawScore,
            rhrAdjustment: rhrAdjustment,
            todayRHR: todayRHR,
            yesterdayRHR: resolvedYesterdayRHR,
            baselineRHR: baselineRHR,
            rhrDeltaFromBaseline: rhrDeltaFromBaseline,
            rhrBaselineDays: rhrBaselineValues.count,
            displayRHR: validatedRHR(input.displayRHR),
            displayRHRDate: validatedRHR(input.displayRHR) != nil ? input.displayRHRDate : nil,
            timeOfDayAdjustment: timeAdjustment,
            evaluationDate: input.evaluationDate
        )

        let score = ConditionScore(score: clampedScore, date: input.evaluationDate, contributions: contributions, detail: detail)

        return Output(score: score, baselineStatus: baselineStatus, contributions: contributions)
    }

    // MARK: - Private

    private func computeDailyAverages(from samples: [HRVSample]) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }

        return grouped.compactMap { date, samples in
            guard !samples.isEmpty else { return nil }
            let avg = samples.map(\.value).reduce(0, +) / Double(samples.count)
            return (date: date, value: avg)
        }
        .sorted { $0.date > $1.date }
    }

    private func computeDailyRHR(from samples: [Input.RHRDailyAverage]) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }

        return grouped.compactMap { date, samples in
            let validValues = samples
                .map(\.value)
                .filter { rhrValidRange.contains($0) && $0.isFinite }
            guard let average = average(validValues) else { return nil }
            return (date: date, value: average)
        }
        .sorted { $0.date > $1.date }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard let mean = average(values), !values.isEmpty else { return 0 }
        let variance = values
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / Double(values.count)
        guard variance.isFinite else { return 0 }
        return sqrt(variance)
    }

    private func validatedRHR(_ value: Double?) -> Double? {
        value.flatMap { rhrValidRange.contains($0) ? $0 : nil }
    }

    private func timeOfDayAdjustment(for date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<6: return 6
        case 6..<11: return 3
        case 11..<17: return 0
        case 17..<22: return -3
        default: return -1
        }
    }

    private enum Cache {
        static let shortDate: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter
        }()
    }
}
