import Foundation

/// Input data for the coaching engine
struct CoachingInput: Sendable {
    let conditionScore: ConditionScore?
    let fatigueStates: [MuscleFatigueState]
    let sleepScore: Int?
    let sleepMinutes: Double?
    let deepSleepMinutes: Double?
    let workoutStreak: WorkoutStreak?
    let hrvTrend: TrendAnalysis
    let sleepTrend: TrendAnalysis
    let activeDaysThisWeek: Int
    let weeklyGoalDays: Int
    let daysSinceLastWorkout: Int?
    let workoutSuggestion: WorkoutSuggestion?
    let recentPRExerciseName: String?
    let currentStreakMilestone: Int?
    let weather: WeatherSnapshot?
}

/// Output from the coaching engine
struct CoachingOutput: Sendable {
    let focusInsight: CoachingInsight
    let insightCards: [CoachingInsight]
}

/// Generates personalized coaching insights from health data.
///
/// Uses a priority-based template selection system:
/// - Evaluates all triggers against current data
/// - Selects highest-priority match as the focus message
/// - Additional matches become insight cards (max 3)
struct CoachingEngine: Sendable {

    func generate(from input: CoachingInput) -> CoachingOutput {
        var allInsights: [CoachingInsight] = []

        // Evaluate all trigger categories
        allInsights.append(contentsOf: evaluateWeatherTriggers(input))
        allInsights.append(contentsOf: evaluateRecoveryTriggers(input))
        allInsights.append(contentsOf: evaluateSleepTriggers(input))
        allInsights.append(contentsOf: evaluateTrainingTriggers(input))
        allInsights.append(contentsOf: evaluateMotivationTriggers(input))
        allInsights.append(contentsOf: evaluateDefaultTriggers(input))

        // Sort by priority (lower rawValue = higher priority)
        allInsights.sort { $0.priority < $1.priority }

        // Focus: highest priority insight
        let focus = allInsights.first ?? defaultFallback()

        // Cards: next 3 insights (different category than focus preferred)
        let cards = Array(
            allInsights
                .dropFirst()
                .prefix(3)
        )

        return CoachingOutput(focusInsight: focus, insightCards: cards)
    }

    // MARK: - Weather Triggers (P2-P5)

    private func evaluateWeatherTriggers(_ input: CoachingInput) -> [CoachingInsight] {
        guard let weather = input.weather else {
            return [CoachingInsight(
                id: "weather-unavailable-default",
                priority: .ambient,
                category: .weather,
                title: String(localized: "A good day for exercise"),
                message: String(localized: "Weather data is unavailable, but indoor exercise is always a great option."),
                iconName: "figure.strengthtraining.traditional"
            )]
        }
        var results: [CoachingInsight] = []

        // P2: Extreme heat (feels like 35°C+)
        if weather.isExtremeHeat {
            results.append(CoachingInsight(
                id: "weather-extreme-heat",
                priority: .high,
                category: .weather,
                title: String(localized: "Extreme heat warning"),
                message: String(localized: "Try indoor workouts or early morning/evening sessions. Stay well hydrated."),
                iconName: "sun.max.trianglebadge.exclamationmark.fill"
            ))
        }

        // P2: Freezing (feels like 0°C or below)
        if weather.isFreezing {
            results.append(CoachingInsight(
                id: "weather-freezing",
                priority: .high,
                category: .weather,
                title: String(localized: "Freezing cold warning"),
                message: String(localized: "Warm up thoroughly and consider indoor workouts. Cold weather increases injury risk."),
                iconName: "thermometer.snowflake"
            ))
        }

        // P3: Very high UV (8+)
        if weather.isHighUV {
            results.append(CoachingInsight(
                id: "weather-high-uv",
                priority: .medium,
                category: .weather,
                title: String(localized: "Very high UV (UV \(weather.uvIndex))"),
                message: String(localized: "Apply sunscreen and wear a hat for outdoor workouts. Exercise in the shade when possible."),
                iconName: "sun.max.fill"
            ))
        }

        // P4: Rain/Snow — indoor suggestion
        switch weather.condition {
        case .rain, .heavyRain, .thunderstorm:
            results.append(CoachingInsight(
                id: "weather-rain-indoor",
                priority: .standard,
                category: .weather,
                title: String(localized: "Rain forecast — indoor workout recommended"),
                message: String(localized: "Today is a great day for indoor strength training or a home workout."),
                iconName: "cloud.rain.fill"
            ))
        case .snow, .sleet:
            results.append(CoachingInsight(
                id: "weather-snow-indoor",
                priority: .standard,
                category: .weather,
                title: String(localized: "Snow/sleet — indoor workout recommended"),
                message: String(localized: "Outdoor exercise on slippery surfaces risks injury. Stay safe and train indoors."),
                iconName: "cloud.snow.fill"
            ))
        default:
            break
        }

        // P4: High humidity (80%+)
        if weather.isHighHumidity, !weather.isExtremeHeat {
            let humidityPercent = Int(weather.humidity * 100)
            results.append(CoachingInsight(
                id: "weather-high-humidity",
                priority: .standard,
                category: .weather,
                title: String(localized: "High humidity (\(humidityPercent)%)"),
                message: String(localized: "High humidity makes it harder for your body to cool down. Lower the intensity and hydrate frequently."),
                iconName: "humidity.fill"
            ))
        }

        // P5: Favorable outdoor weather
        if weather.isFavorableOutdoor, weather.isDaytime, results.isEmpty {
            results.append(CoachingInsight(
                id: "weather-outdoor-favorable",
                priority: .low,
                category: .weather,
                title: String(localized: "Great weather for outdoor exercise"),
                message: String(localized: "Perfect conditions for a run or a walk."),
                iconName: "sun.and.horizon.fill"
            ))
        }

        return results
    }

    // MARK: - Recovery Triggers (P1-P2)

    private func evaluateRecoveryTriggers(_ input: CoachingInput) -> [CoachingInsight] {
        var results: [CoachingInsight] = []

        // P1: Condition warning + falling trend
        if let score = input.conditionScore,
           score.status == .warning,
           input.hrvTrend.direction == .falling,
           input.hrvTrend.consecutiveDays >= 3 {
            results.append(CoachingInsight(
                id: "recovery-warning-trend",
                priority: .critical,
                category: .recovery,
                title: String(localized: "Recovery is urgent"),
                message: String(localized: "Your HRV has been declining for \(input.hrvTrend.consecutiveDays) consecutive days and your condition is at warning level. Take a full rest day today. Focus on sleep and hydration."),
                iconName: "exclamationmark.triangle.fill"
            ))
        }

        // P1: Condition warning (no trend data)
        if let score = input.conditionScore,
           score.status == .warning,
           input.hrvTrend.direction != .falling {
            results.append(CoachingInsight(
                id: "recovery-warning",
                priority: .critical,
                category: .recovery,
                title: String(localized: "Recovery is needed"),
                message: String(localized: "Your condition is low. Stick to a light walk or stretching today and get to bed early."),
                iconName: "bed.double.fill"
            ))
        }

        // P1: Multiple muscles overtrained
        let overtrainedMuscles = input.fatigueStates.filter { $0.isOverworked }
        if overtrainedMuscles.count >= 3 {
            let muscleNames = overtrainedMuscles.prefix(3).map(\.muscle.rawValue).joined(separator: ", ")
            results.append(CoachingInsight(
                id: "recovery-overtrained",
                priority: .critical,
                category: .recovery,
                title: String(localized: "Signs of overtraining detected"),
                message: String(localized: "\(muscleNames) and \(overtrainedMuscles.count) muscle groups total show very high fatigue. Rest for 1–2 days, then ease back in with light exercise."),
                iconName: "exclamationmark.shield.fill"
            ))
        }

        // P2: Condition tired
        if let score = input.conditionScore, score.status == .tired {
            results.append(CoachingInsight(
                id: "recovery-tired",
                priority: .high,
                category: .recovery,
                title: String(localized: "Fatigue is building up"),
                message: String(localized: "Keep it light today. Low-intensity activities like stretching or yoga can help with recovery."),
                iconName: "figure.mind.and.body"
            ))
        }

        // P2: HRV falling 3+ days
        if let score = input.conditionScore,
           score.status != .warning && score.status != .tired,
           input.hrvTrend.direction == .falling,
           input.hrvTrend.consecutiveDays >= 3 {
            results.append(CoachingInsight(
                id: "recovery-hrv-falling",
                priority: .high,
                category: .recovery,
                title: String(localized: "Condition is trending down"),
                message: String(localized: "Your HRV has been declining for \(input.hrvTrend.consecutiveDays) days. Reduce training volume to 70% and try to get 30 more minutes of sleep."),
                iconName: "arrow.down.right.circle.fill"
            ))
        }

        return results
    }

    // MARK: - Sleep Triggers (P2-P5)

    private func evaluateSleepTriggers(_ input: CoachingInput) -> [CoachingInsight] {
        var results: [CoachingInsight] = []

        // P2: Severe sleep debt (2+ days of < 6h)
        if let minutes = input.sleepMinutes, minutes < 360, minutes > 0 {
            if input.sleepTrend.direction == .falling {
                results.append(CoachingInsight(
                    id: "sleep-debt-critical",
                    priority: .high,
                    category: .sleep,
                    title: String(localized: "Sleep debt is accumulating"),
                    message: String(localized: "You only slept \(formatHoursMinutes(minutes)) last night. Sleep debt slows recovery and increases injury risk. Get to bed early tonight."),
                    iconName: "moon.zzz.fill",
                    actionHint: "sleepDetail"
                ))
            } else {
                results.append(CoachingInsight(
                    id: "sleep-short",
                    priority: .medium,
                    category: .sleep,
                    title: String(localized: "Sleep was insufficient"),
                    message: String(localized: "You only got \(formatHoursMinutes(minutes)) of sleep last night. Skip high-intensity training today and focus on recovery."),
                    iconName: "moon.fill",
                    actionHint: "sleepDetail"
                ))
            }
        }

        // P5: Deep sleep improving
        if let deep = input.deepSleepMinutes, deep > 90,
           input.sleepTrend.direction == .rising {
            results.append(CoachingInsight(
                id: "sleep-deep-improving",
                priority: .low,
                category: .sleep,
                title: String(localized: "Deep sleep is improving"),
                message: String(localized: "Deep sleep at \(formatHoursMinutes(deep)) — looking good. Keep your current sleep routine. Deep sleep is key for muscle recovery and hormone balance."),
                iconName: "sparkles",
                actionHint: "sleepDetail"
            ))
        }

        // P5: Good sleep score
        if let score = input.sleepScore, score >= 80 {
            results.append(CoachingInsight(
                id: "sleep-quality-good",
                priority: .low,
                category: .sleep,
                title: String(localized: "Sleep quality is excellent"),
                message: String(localized: "Last night's sleep score was \(score) — outstanding. Well rested means your workout will be extra effective today."),
                iconName: "moon.stars.fill",
                actionHint: "sleepDetail"
            ))
        }

        // P6: Sleep score declining
        if let score = input.sleepScore, score < 60, score > 0,
           input.sleepTrend.direction == .falling {
            results.append(CoachingInsight(
                id: "sleep-quality-declining",
                priority: .info,
                category: .sleep,
                title: String(localized: "Sleep quality is declining"),
                message: String(localized: "Your sleep score is trending downward. Try reducing screen time an hour before bed and limiting caffeine to before 2 PM."),
                iconName: "moon.haze.fill",
                actionHint: "sleepDetail"
            ))
        }

        return results
    }

    // MARK: - Training Triggers (P3-P7)

    private func evaluateTrainingTriggers(_ input: CoachingInput) -> [CoachingInsight] {
        var results: [CoachingInsight] = []

        // P3: Specific muscle high fatigue
        let highFatigueMuscles = input.fatigueStates.filter {
            $0.fatigueLevel.rawValue >= 7 && $0.fatigueLevel.rawValue < 9
        }
        let lowFatigueMuscles = input.fatigueStates.filter { $0.isRecovered }

        if !highFatigueMuscles.isEmpty, !lowFatigueMuscles.isEmpty {
            let avoidNames = highFatigueMuscles.prefix(2).map(\.muscle.rawValue).joined(separator: ", ")
            let targetNames = lowFatigueMuscles.prefix(2).map(\.muscle.rawValue).joined(separator: ", ")
            results.append(CoachingInsight(
                id: "training-muscle-switch",
                priority: .medium,
                category: .training,
                title: String(localized: "Switch muscle groups"),
                message: String(localized: "\(avoidNames) fatigue is high. Focus on \(targetNames) today for a more effective session."),
                iconName: "arrow.triangle.swap",
                actionHint: "startWorkout"
            ))
        }

        // P4: Weekly goal approaching
        let remaining = Swift.max(0, input.weeklyGoalDays - input.activeDaysThisWeek)
        if remaining > 0, remaining <= 2 {
            results.append(CoachingInsight(
                id: "training-goal-near",
                priority: .standard,
                category: .training,
                title: String(localized: "Almost at your weekly goal"),
                message: String(localized: "\(remaining) day(s) left to hit your weekly target. Even a short workout counts — finish strong!"),
                iconName: "flag.fill"
            ))
        }

        // P4: Weekly goal achieved (guard weeklyGoalDays > 0 to avoid false positive)
        if remaining == 0, input.weeklyGoalDays > 0, input.activeDaysThisWeek >= input.weeklyGoalDays {
            results.append(CoachingInsight(
                id: "training-goal-achieved",
                priority: .standard,
                category: .motivation,
                title: String(localized: "Weekly goal achieved!"),
                message: String(localized: "You worked out \(input.activeDaysThisWeek) days this week. Consistency is your greatest strength."),
                iconName: "trophy.fill"
            ))
        }

        // P5: Condition good/excellent + rising HRV → push harder
        if let score = input.conditionScore,
           (score.status == .good || score.status == .excellent),
           input.hrvTrend.direction == .rising {
            let intensityLabel = score.status == .excellent
                ? String(localized: "high-intensity")
                : String(localized: "moderate-to-high intensity")
            results.append(CoachingInsight(
                id: "training-push-harder",
                priority: .low,
                category: .training,
                title: String(localized: "Your condition is on the rise"),
                message: String(localized: "HRV has been rising for \(input.hrvTrend.consecutiveDays) consecutive days. Great timing to try a \(intensityLabel) workout."),
                iconName: "flame.fill",
                actionHint: "startWorkout"
            ))
        }

        // P5: Condition good, no specific trend
        if let score = input.conditionScore,
           score.status == .good,
           input.hrvTrend.direction == .stable {
            results.append(CoachingInsight(
                id: "training-steady",
                priority: .low,
                category: .training,
                title: String(localized: "Condition is stable"),
                message: String(localized: "Today is ideal for maintaining your usual training intensity. Consistency is the key to growth."),
                iconName: "figure.strengthtraining.traditional",
                actionHint: "startWorkout"
            ))
        }

        // P5: Condition excellent
        if let score = input.conditionScore,
           score.status == .excellent,
           input.hrvTrend.direction != .rising {
            results.append(CoachingInsight(
                id: "training-excellent",
                priority: .low,
                category: .training,
                title: String(localized: "Peak condition"),
                message: String(localized: "Set an ambitious goal today. It's the perfect time to chase a PR or try a new exercise."),
                iconName: "star.fill",
                actionHint: "startWorkout"
            ))
        }

        // P5: Condition fair, stable
        if let score = input.conditionScore, score.status == .fair {
            if let minutes = input.sleepMinutes, minutes < 360 {
                results.append(CoachingInsight(
                    id: "training-fair-sleep",
                    priority: .low,
                    category: .training,
                    title: String(localized: "Keep it light today"),
                    message: String(localized: "Sleep was short, so stick to light exercise today. Pushing too hard will only make tomorrow worse."),
                    iconName: "figure.walk",
                    actionHint: "startWorkout"
                ))
            } else {
                results.append(CoachingInsight(
                    id: "training-fair-normal",
                    priority: .low,
                    category: .training,
                    title: String(localized: "Moderate exercise is best"),
                    message: String(localized: "Your condition is average. Train at a moderate intensity and avoid overexertion."),
                    iconName: "figure.run",
                    actionHint: "startWorkout"
                ))
            }
        }

        // P7: Workout gap
        if let daysSince = input.daysSinceLastWorkout, daysSince >= 3 {
            results.append(CoachingInsight(
                id: "training-gap",
                priority: .ambient,
                category: .training,
                title: String(localized: "\(daysSince) days since your last workout"),
                message: String(localized: "The longer the break, the harder it is to restart. Get moving today — even a 10-minute walk helps."),
                iconName: "figure.walk.motion",
                actionHint: "startWorkout"
            ))
        }

        // Workout recommendation card (if suggestion exists)
        if let suggestion = input.workoutSuggestion, !suggestion.isRestDay {
            let muscleText = suggestion.focusMuscles.prefix(3).map(\.rawValue).joined(separator: ", ")
            let exerciseCount = suggestion.exercises.count
            results.append(CoachingInsight(
                id: "training-recommendation",
                priority: .standard,
                category: .training,
                title: String(localized: "Today's recommended workout"),
                message: String(localized: "\(exerciseCount) exercises focusing on \(muscleText). Built around your most recovered muscles."),
                iconName: "sparkles.rectangle.stack.fill",
                actionHint: "workoutRecommendation"
            ))
        } else if let suggestion = input.workoutSuggestion, suggestion.isRestDay {
            results.append(CoachingInsight(
                id: "training-rest-day",
                priority: .standard,
                category: .recovery,
                title: String(localized: "Today is a recovery day"),
                message: String(localized: "Most muscles are still recovering. Light stretching or a walk will help improve circulation."),
                iconName: "leaf.fill"
            ))
        }

        return results
    }

    // MARK: - Motivation Triggers (P8)

    private func evaluateMotivationTriggers(_ input: CoachingInput) -> [CoachingInsight] {
        var results: [CoachingInsight] = []

        // P8: PR achieved
        if let prName = input.recentPRExerciseName {
            results.append(CoachingInsight(
                id: "motivation-pr",
                priority: .celebration,
                category: .motivation,
                title: String(localized: "New PR achieved!"),
                message: String(localized: "You set a personal record on \(prName). That's the payoff of consistent effort!"),
                iconName: "medal.fill"
            ))
        }

        // P8: Streak milestone
        if let milestone = input.currentStreakMilestone, milestone > 0 {
            let milestoneText: String
            switch milestone {
            case 7: milestoneText = String(localized: "1 Week")
            case 14: milestoneText = String(localized: "2 Weeks")
            case 30: milestoneText = String(localized: "1 Month")
            case 60: milestoneText = String(localized: "2 Months")
            case 90: milestoneText = String(localized: "3 Months")
            case 100: milestoneText = String(localized: "100 Days")
            case 365: milestoneText = String(localized: "1 Year")
            default: milestoneText = String(localized: "\(milestone) Days")
            }
            results.append(CoachingInsight(
                id: "motivation-streak-\(milestone)",
                priority: .celebration,
                category: .motivation,
                title: String(localized: "\(milestoneText) workout streak!"),
                message: String(localized: "\(milestone) consecutive days of exercise. Incredible consistency! Keep the habit going."),
                iconName: "flame.circle.fill"
            ))
        }

        // P8: Monthly consistency high
        if let streak = input.workoutStreak, streak.monthlyPercentage >= 0.8 {
            results.append(CoachingInsight(
                id: "motivation-monthly-high",
                priority: .celebration,
                category: .motivation,
                title: String(localized: "Over 80% of monthly goal reached!"),
                message: String(localized: "You've hit \(streak.monthlyCount)/\(streak.monthlyGoal) days this month. Go all the way!"),
                iconName: "chart.bar.fill"
            ))
        }

        return results
    }

    // MARK: - Default Triggers (P9)

    private func evaluateDefaultTriggers(_ input: CoachingInput) -> [CoachingInsight] {
        var results: [CoachingInsight] = []

        // P9: No score yet
        if input.conditionScore == nil {
            let remaining = Swift.max(0, input.weeklyGoalDays - input.activeDaysThisWeek)
            if remaining > 0 {
                results.append(CoachingInsight(
                    id: "default-no-score-goal",
                    priority: .fallback,
                    category: .general,
                    title: String(localized: "Gathering your data"),
                    message: String(localized: "Your condition score isn't ready yet. A workout today brings you one step closer to your weekly goal."),
                    iconName: "chart.line.uptrend.xyaxis"
                ))
            } else {
                results.append(CoachingInsight(
                    id: "default-no-score",
                    priority: .fallback,
                    category: .general,
                    title: String(localized: "Gathering your data"),
                    message: String(localized: "Wear your Apple Watch for a few days to collect data, and you'll receive personalized coaching."),
                    iconName: "applewatch"
                ))
            }
        }

        return results
    }

    // MARK: - Fallback

    private func defaultFallback() -> CoachingInsight {
        CoachingInsight(
            id: "fallback-default",
            priority: .fallback,
            category: .general,
            title: String(localized: "Have a healthy day"),
            message: String(localized: "Consistent exercise and quality sleep are the best investments in your health."),
            iconName: "heart.fill"
        )
    }

    // MARK: - Formatting

    private func formatHoursMinutes(_ minutes: Double) -> String {
        // Clamp to physical range: 0-1440 minutes (24h) per Correction #84
        let clamped = Swift.max(0, Swift.min(minutes, 1440))
        let total = Int(clamped)
        let h = total / 60
        let m = total % 60
        if h > 0, m > 0 { return String(localized: "\(h)h \(m)min") }
        if h > 0 { return String(localized: "\(h)h") }
        return String(localized: "\(m)min")
    }
}
