import Foundation

extension HealthQueryKind {
    var symbolName: String {
        switch self {
        case .latestWorkout: "figure.run"
        case .workoutSummary: "chart.bar.fill"
        case .strengthSets: "dumbbell.fill"
        case .personalRecord: "medal.fill"
        case .cardioDetail: "figure.outdoor.cycle"
        case .latestBody: "scalemass.fill"
        case .bodyTrend: "chart.xyaxis.line"
        case .sleep: "moon.stars.fill"
        case .condition: "heart.circle.fill"
        case .metricComparison: "chart.bar.xaxis"
        case .workoutComparison: "arrow.left.arrow.right"
        case .memoSearch: "text.magnifyingglass"
        case .report: "doc.text.fill"
        case .longAnalysis: "waveform.path.ecg"
        }
    }

    var displayName: String {
        switch self {
        case .latestWorkout: String(localized: "Latest workout")
        case .workoutSummary: String(localized: "Workout summary")
        case .strengthSets: String(localized: "Strength sets")
        case .personalRecord: String(localized: "Personal record")
        case .cardioDetail: String(localized: "Cardio detail")
        case .latestBody: String(localized: "Latest body measurements")
        case .bodyTrend: String(localized: "Body trend")
        case .sleep: String(localized: "Sleep")
        case .condition: String(localized: "Condition")
        case .metricComparison: String(localized: "Metric comparison")
        case .workoutComparison: String(localized: "Workout comparison")
        case .memoSearch: String(localized: "Workout notes")
        case .report: String(localized: "Health report")
        case .longAnalysis: String(localized: "Health analysis")
        }
    }
}

extension HealthQueryPeriod {
    var displayName: String {
        switch self {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .thisWeek: String(localized: "This week")
        case .lastWeek: String(localized: "Last week")
        case .thisMonth: String(localized: "This month")
        case .lastMonth: String(localized: "Last month")
        case .last7Days: String(localized: "Last 7 days")
        case .last30Days: String(localized: "Last 30 days")
        case .last90Days: String(localized: "Last 90 days")
        case .last365Days: String(localized: "Last 365 days")
        }
    }
}

extension HealthQueryUnit {
    var symbol: String {
        switch self {
        case .count: ""
        case .seconds: "s"
        case .meters: "m"
        case .kilograms: "kg"
        case .kilocalories: "kcal"
        case .bodyMassIndex: "kg/m²"
        case .percent: "%"
        case .bpm: "bpm"
        case .milliseconds: "ms"
        case .score: "/100"
        case .kilogramRepetitions: "kg·reps"
        case .secondsPerKilometer: "s/km"
        }
    }

    func formatted(_ value: Double) -> String {
        guard value.isFinite else { return String(localized: "Unavailable") }
        switch self {
        case .seconds:
            let total = max(0, Int(value))
            let hours = total / 3_600
            let minutes = (total % 3_600) / 60
            let seconds = total % 60
            return hours > 0 ? "\(hours):\(minutes.formatted(.number.precision(.integerLength(2)))):\(seconds.formatted(.number.precision(.integerLength(2))))" : "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
        case .secondsPerKilometer:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
        case .meters where abs(value) >= 1_000:
            return (value / 1_000).formatted(.number.precision(.fractionLength(0...2)))
        case .percent, .kilograms, .kilocalories, .kilogramRepetitions, .bodyMassIndex:
            return value.formatted(.number.precision(.fractionLength(0...1)))
        default:
            return value.formatted(.number.precision(.fractionLength(0...0)))
        }
    }

    func displayUnit(for value: Double) -> String {
        self == .meters && abs(value) >= 1_000 ? "km" : symbol
    }
}

