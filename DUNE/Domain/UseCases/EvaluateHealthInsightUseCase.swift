import Foundation

/// Evaluates new HealthKit samples against baselines to produce actionable insights.
/// Pure domain logic — no HealthKit or SwiftData dependencies.
enum EvaluateHealthInsightUseCase: Sendable {

    // MARK: - Configuration

    private enum Thresholds {
        static let hrvDeviationPercent = 0.20   // ±20% from 7-day mean
        static let rhrDeviationPercent = 0.15   // ±15% from 7-day mean
        static let minimumBaselineDays = 7
        static let stepGoal = 10_000.0
    }

    // MARK: - HRV Anomaly

    /// Evaluates if a new HRV value deviates significantly from the 7-day baseline.
    /// - Parameters:
    ///   - todayValue: Today's HRV (ms SDNN).
    ///   - recentDailyAverages: Past daily averages (oldest-first), at least 7 entries.
    /// - Returns: An insight if anomaly detected, nil otherwise.
    static func evaluateHRV(
        todayValue: Double,
        recentDailyAverages: [Double]
    ) -> HealthInsight? {
        guard todayValue > 0, todayValue.isFinite else { return nil }
        guard recentDailyAverages.count >= Thresholds.minimumBaselineDays else { return nil }

        let baseline = recentDailyAverages.reduce(0, +) / Double(recentDailyAverages.count)
        guard baseline > 0 else { return nil }

        let deviation = (todayValue - baseline) / baseline
        guard abs(deviation) >= Thresholds.hrvDeviationPercent else { return nil }

        let percentText = formatPercent(abs(deviation))
        let direction = deviation > 0
            ? String(localized: "higher than usual")
            : String(localized: "lower than usual")

        return HealthInsight(
            type: .hrvAnomaly,
            title: String(localized: "HRV Change Detected"),
            body: String(localized: "Today's HRV \(Int(todayValue))ms — \(percentText) \(direction)"),
            severity: .attention,
            date: Date()
        )
    }

    // MARK: - RHR Anomaly

    /// Evaluates if a new RHR value deviates significantly from the 7-day baseline.
    static func evaluateRHR(
        todayValue: Double,
        recentDailyAverages: [Double]
    ) -> HealthInsight? {
        guard todayValue > 0, todayValue.isFinite else { return nil }
        guard recentDailyAverages.count >= Thresholds.minimumBaselineDays else { return nil }

        let baseline = recentDailyAverages.reduce(0, +) / Double(recentDailyAverages.count)
        guard baseline > 0 else { return nil }

        let deviation = (todayValue - baseline) / baseline
        guard abs(deviation) >= Thresholds.rhrDeviationPercent else { return nil }

        let percentText = formatPercent(abs(deviation))
        let direction = deviation > 0
            ? String(localized: "higher than usual")
            : String(localized: "lower than usual")

        return HealthInsight(
            type: .rhrAnomaly,
            title: String(localized: "Resting Heart Rate Alert"),
            body: String(localized: "RHR \(Int(todayValue))bpm — \(percentText) \(direction)"),
            severity: .attention,
            date: Date()
        )
    }

    // MARK: - Sleep Complete

    /// Creates an insight when sleep data recording is complete.
    static func evaluateSleepComplete(
        totalMinutes: Double
    ) -> HealthInsight? {
        guard totalMinutes > 0, totalMinutes.isFinite else { return nil }

        let hours = Int(totalMinutes) / 60
        let mins = Int(totalMinutes) % 60

        return HealthInsight(
            type: .sleepComplete,
            title: String(localized: "Sleep Recorded"),
            body: String(localized: "Last night: \(hours)h \(mins)m of sleep"),
            severity: .informational,
            date: Date()
        )
    }

    // MARK: - Step Goal

    /// Creates an insight when the step count goal is reached.
    static func evaluateStepGoal(
        todaySteps: Double
    ) -> HealthInsight? {
        guard todaySteps >= Thresholds.stepGoal else { return nil }

        return HealthInsight(
            type: .stepGoal,
            title: String(localized: "Step Goal Reached!"),
            body: String(localized: "\(Int(todaySteps)) steps today"),
            severity: .celebration,
            date: Date()
        )
    }

    // MARK: - Weight Update

    /// Creates an insight for a new weight measurement.
    static func evaluateWeight(
        newValue: Double,
        previousValue: Double?
    ) -> HealthInsight? {
        guard newValue > 0, newValue.isFinite, newValue <= 500 else { return nil }

        let bodyText: String
        if let prev = previousValue, prev > 0, prev.isFinite {
            let change = newValue - prev
            let sign = change >= 0 ? "+" : ""
            bodyText = String(localized: "Weight: \(newValue.formatted(.number.precision(.fractionLength(1))))kg (\(sign)\(change.formatted(.number.precision(.fractionLength(1)))))")
        } else {
            bodyText = String(localized: "Weight: \(newValue.formatted(.number.precision(.fractionLength(1))))kg")
        }

        return HealthInsight(
            type: .weightUpdate,
            title: String(localized: "Weight Recorded"),
            body: bodyText,
            severity: .informational,
            date: Date()
        )
    }

    // MARK: - Body Fat Update

    /// Creates an insight for a new body fat measurement.
    static func evaluateBodyFat(
        newValue: Double
    ) -> HealthInsight? {
        guard newValue > 0, newValue <= 100, newValue.isFinite else { return nil }

        return HealthInsight(
            type: .bodyFatUpdate,
            title: String(localized: "Body Fat Recorded"),
            body: String(localized: "Body fat: \(newValue.formatted(.number.precision(.fractionLength(1))))%"),
            severity: .informational,
            date: Date()
        )
    }

    // MARK: - BMI Update

    /// Creates an insight for a new BMI measurement.
    static func evaluateBMI(
        newValue: Double
    ) -> HealthInsight? {
        guard newValue > 0, newValue <= 100, newValue.isFinite else { return nil }

        return HealthInsight(
            type: .bmiUpdate,
            title: String(localized: "BMI Updated"),
            body: String(localized: "BMI: \(newValue.formatted(.number.precision(.fractionLength(1))))"),
            severity: .informational,
            date: Date()
        )
    }

    // MARK: - Workout PR

    /// Creates an insight for a workout personal record achievement.
    /// - Parameters:
    ///   - activityName: Localized activity display name.
    ///   - recordTypeNames: Localized names of achieved PR types (resolved at call site).
    static func evaluateWorkoutPR(
        activityName: String,
        recordTypeNames: [String]
    ) -> HealthInsight? {
        guard !recordTypeNames.isEmpty else { return nil }

        let typesText = recordTypeNames.joined(separator: ", ")

        return HealthInsight(
            type: .workoutPR,
            title: String(localized: "New Personal Record!"),
            body: String(localized: "\(activityName): \(typesText)"),
            severity: .celebration,
            date: Date()
        )
    }

    /// Creates a representative insight for workout reward events.
    /// Keeps notification cardinality at one alert per workout.
    static func evaluateWorkoutReward(
        activityName: String,
        representativeEvent: WorkoutRewardEvent
    ) -> HealthInsight? {
        guard !activityName.isEmpty else { return nil }

        let title: String
        switch representativeEvent.kind {
        case .levelUp:
            title = String(localized: "Level Up!")
        case .badgeUnlocked:
            title = String(localized: "New Badge Unlocked")
        case .personalRecord:
            title = String(localized: "New Personal Record!")
        case .milestone:
            title = String(localized: "Milestone Reached!")
        }

        let body = representativeEvent.detail.isEmpty
            ? activityName
            : representativeEvent.detail

        return HealthInsight(
            type: .workoutPR,
            title: title,
            body: body,
            severity: .celebration,
            date: representativeEvent.date
        )
    }

    // MARK: - Private

    private static func formatPercent(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }
}
