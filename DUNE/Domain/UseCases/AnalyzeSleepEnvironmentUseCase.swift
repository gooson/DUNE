import Foundation

protocol SleepEnvironmentAnalyzing: Sendable {
    func execute(input: AnalyzeSleepEnvironmentUseCase.Input) -> SleepEnvironmentAnalysis?
}

/// Correlates outdoor temperature/humidity with sleep quality.
///
/// Sorts paired data by sleep score, compares top-quartile vs bottom-quartile weather
/// conditions to identify optimal temperature and humidity ranges.
struct AnalyzeSleepEnvironmentUseCase: SleepEnvironmentAnalyzing, Sendable {

    struct Input: Sendable {
        let pairs: [DayPair]

        struct DayPair: Sendable {
            let date: Date
            let sleepScore: Int
            let avgTemperatureCelsius: Double
            let avgHumidityPercent: Double
        }
    }

    func execute(input: Input) -> SleepEnvironmentAnalysis? {
        let pairs = input.pairs.filter { $0.sleepScore > 0 }
        guard pairs.count >= 7 else { return nil }

        let sortedByScore = pairs.sorted { $0.sleepScore > $1.sleepScore }
        let quartileSize = max(1, pairs.count / 4)
        let topQuartile = Array(sortedByScore.prefix(quartileSize))
        let bottomQuartile = Array(sortedByScore.suffix(quartileSize))

        let tempInsight = buildInsight(
            topQuartile: topQuartile.map(\.avgTemperatureCelsius),
            bottomQuartile: bottomQuartile.map(\.avgTemperatureCelsius),
            topScores: topQuartile.map(\.sleepScore),
            bottomScores: bottomQuartile.map(\.sleepScore),
            unit: "°C",
            label: String(localized: "temperature")
        )

        let humidityInsight = buildInsight(
            topQuartile: topQuartile.map(\.avgHumidityPercent),
            bottomQuartile: bottomQuartile.map(\.avgHumidityPercent),
            topScores: topQuartile.map(\.sleepScore),
            bottomScores: bottomQuartile.map(\.sleepScore),
            unit: "%",
            label: String(localized: "humidity")
        )

        let confidence: SleepEnvironmentAnalysis.Confidence = switch pairs.count {
        case ..<14: .low
        case 14..<30: .medium
        default: .high
        }

        let dailyPairs = pairs.map {
            SleepEnvironmentAnalysis.DayPair(
                date: $0.date,
                sleepScore: $0.sleepScore,
                temperature: $0.avgTemperatureCelsius,
                humidity: $0.avgHumidityPercent
            )
        }

        return SleepEnvironmentAnalysis(
            dataPointCount: pairs.count,
            confidence: confidence,
            temperatureInsight: tempInsight,
            humidityInsight: humidityInsight,
            dailyPairs: dailyPairs
        )
    }

    private func buildInsight(
        topQuartile: [Double],
        bottomQuartile: [Double],
        topScores: [Int],
        bottomScores: [Int],
        unit: String,
        label: String
    ) -> SleepEnvironmentAnalysis.EnvironmentInsight? {
        guard !topQuartile.isEmpty, !bottomQuartile.isEmpty else { return nil }

        let topAvg = topQuartile.reduce(0, +) / Double(topQuartile.count)
        let topStdDev = stdDev(topQuartile, mean: topAvg)
        let bestScoreAvg = Double(topScores.reduce(0, +)) / Double(topScores.count)
        let worstScoreAvg = Double(bottomScores.reduce(0, +)) / Double(bottomScores.count)

        let rangeLow = topAvg - topStdDev
        let rangeHigh = topAvg + topStdDev

        let message = String(
            localized: "Best sleep at \(Int(rangeLow))-\(Int(rangeHigh))\(unit) \(label)"
        )

        return .init(
            bestSleepAvgScore: bestScoreAvg,
            worstSleepAvgScore: worstScoreAvg,
            optimalRange: rangeLow...rangeHigh,
            message: message
        )
    }

    private func stdDev(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let sumSq = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumSq / Double(values.count)).squareRoot()
    }
}
