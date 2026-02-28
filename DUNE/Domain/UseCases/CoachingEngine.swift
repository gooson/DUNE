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
        guard let weather = input.weather else { return [] }
        var results: [CoachingInsight] = []

        // P2: Extreme heat (feels like 35°C+)
        if weather.isExtremeHeat {
            let temp = Int(weather.feelsLike)
            results.append(CoachingInsight(
                id: "weather-extreme-heat",
                priority: .high,
                category: .weather,
                title: "극심한 더위 주의",
                message: "체감 온도 \(temp)°C — 실내 운동이나 이른 아침/저녁 세션을 권합니다. 수분 보충을 충분히 하세요.",
                iconName: "sun.max.trianglebadge.exclamationmark.fill"
            ))
        }

        // P2: Freezing (feels like 0°C or below)
        if weather.isFreezing {
            let temp = Int(weather.feelsLike)
            results.append(CoachingInsight(
                id: "weather-freezing",
                priority: .high,
                category: .weather,
                title: "한파 주의",
                message: "체감 온도 \(temp)°C — 워밍업을 충분히 하고 실내 운동을 고려하세요. 한랭 환경은 부상 위험을 높입니다.",
                iconName: "thermometer.snowflake"
            ))
        }

        // P3: Very high UV (8+)
        if weather.isHighUV {
            results.append(CoachingInsight(
                id: "weather-high-uv",
                priority: .medium,
                category: .weather,
                title: "자외선 매우 높음 (UV \(weather.uvIndex))",
                message: "야외 운동 시 자외선 차단제를 바르고 모자를 착용하세요. 가능하면 그늘에서 운동하세요.",
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
                title: "비 예보 — 실내 운동 추천",
                message: "오늘은 실내 근력 운동이나 홈트레이닝이 좋은 날입니다.",
                iconName: "cloud.rain.fill"
            ))
        case .snow, .sleet:
            results.append(CoachingInsight(
                id: "weather-snow-indoor",
                priority: .standard,
                category: .weather,
                title: "눈/진눈깨비 — 실내 운동 추천",
                message: "미끄러운 노면에서의 야외 운동은 부상 위험이 있습니다. 실내에서 안전하게 운동하세요.",
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
                title: "높은 습도 (\(humidityPercent)%)",
                message: "높은 습도는 체온 조절을 어렵게 합니다. 운동 강도를 낮추고 수분을 자주 보충하세요.",
                iconName: "humidity.fill"
            ))
        }

        // P5: Favorable outdoor weather
        if weather.isFavorableOutdoor, weather.isDaytime, results.isEmpty {
            let temp = Int(weather.temperature)
            results.append(CoachingInsight(
                id: "weather-outdoor-favorable",
                priority: .low,
                category: .weather,
                title: "야외 운동하기 좋은 날씨",
                message: "\(temp)°C — 러닝이나 산책을 즐기기에 좋은 날씨입니다.",
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
                title: "회복이 시급합니다",
                message: "HRV가 \(input.hrvTrend.consecutiveDays)일 연속 하락 중이고 컨디션이 경고 수준입니다. 오늘은 완전한 휴식을 권합니다. 충분한 수면과 수분 섭취에 집중하세요.",
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
                title: "회복이 필요합니다",
                message: "컨디션이 낮은 상태입니다. 오늘은 가벼운 산책이나 스트레칭 정도만 하시고, 일찍 취침하세요.",
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
                title: "과훈련 징후가 감지되었습니다",
                message: "\(muscleNames) 등 \(overtrainedMuscles.count)개 근육군의 피로도가 매우 높습니다. 1-2일 휴식 후 가벼운 운동부터 재개하세요.",
                iconName: "exclamationmark.shield.fill"
            ))
        }

        // P2: Condition tired
        if let score = input.conditionScore, score.status == .tired {
            results.append(CoachingInsight(
                id: "recovery-tired",
                priority: .high,
                category: .recovery,
                title: "피로가 누적되어 있습니다",
                message: "오늘은 가벼운 활동 위주로 진행하세요. 스트레칭이나 요가 같은 저강도 운동이 회복에 도움됩니다.",
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
                title: "컨디션 하락 추세입니다",
                message: "HRV가 \(input.hrvTrend.consecutiveDays)일째 하락 중입니다. 운동 볼륨을 평소의 70%로 줄이고 수면 시간을 30분 늘려보세요.",
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
                    title: "수면 부채가 쌓이고 있습니다",
                    message: "어젯밤 수면이 \(formatHoursMinutes(minutes))로 부족합니다. 수면 부채는 체력 회복을 늦추고 부상 위험을 높입니다. 오늘은 일찍 취침하세요.",
                    iconName: "moon.zzz.fill",
                    actionHint: "sleepDetail"
                ))
            } else {
                results.append(CoachingInsight(
                    id: "sleep-short",
                    priority: .medium,
                    category: .sleep,
                    title: "수면이 부족했습니다",
                    message: "어젯밤 \(formatHoursMinutes(minutes))만 주무셨습니다. 오늘은 고강도 운동을 피하고 회복에 집중하세요.",
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
                title: "깊은 수면이 개선되고 있습니다",
                message: "깊은 수면 \(formatHoursMinutes(deep))으로 양호합니다. 현재 수면 루틴을 유지하세요. 깊은 수면은 근육 회복과 호르몬 분비에 핵심입니다.",
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
                title: "수면 품질이 좋습니다",
                message: "어젯밤 수면 점수 \(score)점으로 우수합니다. 잘 쉬었으니 오늘 운동 효과가 극대화됩니다.",
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
                title: "수면 품질이 떨어지고 있습니다",
                message: "수면 점수가 하락 추세입니다. 취침 1시간 전부터 스크린을 줄이고 카페인은 오후 2시 이전에만 섭취해 보세요.",
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
                title: "부위를 전환하세요",
                message: "\(avoidNames)의 피로도가 높습니다. 오늘은 \(targetNames) 위주로 운동하면 효율적입니다.",
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
                title: "주간 목표에 거의 도달했습니다",
                message: "이번 주 목표까지 \(remaining)일 남았습니다. 짧은 운동이라도 좋으니 목표를 완성하세요!",
                iconName: "flag.fill"
            ))
        }

        // P4: Weekly goal achieved (guard weeklyGoalDays > 0 to avoid false positive)
        if remaining == 0, input.weeklyGoalDays > 0, input.activeDaysThisWeek >= input.weeklyGoalDays {
            results.append(CoachingInsight(
                id: "training-goal-achieved",
                priority: .standard,
                category: .motivation,
                title: "주간 목표를 달성했습니다!",
                message: "이번 주 \(input.activeDaysThisWeek)일 운동을 완료했습니다. 꾸준함이 가장 큰 무기입니다.",
                iconName: "trophy.fill"
            ))
        }

        // P5: Condition good/excellent + rising HRV → push harder
        if let score = input.conditionScore,
           (score.status == .good || score.status == .excellent),
           input.hrvTrend.direction == .rising {
            let intensityLabel = score.status == .excellent ? "고강도" : "중-고강도"
            results.append(CoachingInsight(
                id: "training-push-harder",
                priority: .low,
                category: .training,
                title: "컨디션이 상승 중입니다",
                message: "HRV가 \(input.hrvTrend.consecutiveDays)일 연속 상승 중입니다. \(intensityLabel) 운동을 시도하기 좋은 타이밍입니다.",
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
                title: "컨디션이 안정적입니다",
                message: "오늘은 평소 강도의 운동을 유지하기 좋은 상태입니다. 일관성이 성장의 열쇠입니다.",
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
                title: "최상의 컨디션입니다",
                message: "오늘은 도전적인 목표를 세워보세요. PR 도전이나 새로운 운동을 시도하기에 최적입니다.",
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
                    title: "가볍게 움직이세요",
                    message: "수면이 짧았으니 오늘은 가벼운 운동 위주로 진행하세요. 무리하면 내일 더 피로합니다.",
                    iconName: "figure.walk",
                    actionHint: "startWorkout"
                ))
            } else {
                results.append(CoachingInsight(
                    id: "training-fair-normal",
                    priority: .low,
                    category: .training,
                    title: "적당한 운동이 좋습니다",
                    message: "컨디션이 평균 수준입니다. 중간 강도로 운동하되 무리하지 마세요.",
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
                title: "\(daysSince)일째 운동을 쉬고 있습니다",
                message: "오래 쉬면 다시 시작하기가 어려워집니다. 오늘 가볍게라도 움직여보세요. 10분 산책도 좋습니다.",
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
                title: "오늘의 추천 운동",
                message: "\(muscleText) 중심 \(exerciseCount)가지 운동을 추천합니다. 회복된 근육 위주로 구성했습니다.",
                iconName: "sparkles.rectangle.stack.fill",
                actionHint: "workoutRecommendation"
            ))
        } else if let suggestion = input.workoutSuggestion, suggestion.isRestDay {
            results.append(CoachingInsight(
                id: "training-rest-day",
                priority: .standard,
                category: .recovery,
                title: "오늘은 회복의 날",
                message: "대부분의 근육이 회복 중입니다. 가벼운 스트레칭이나 산책으로 혈류를 촉진하세요.",
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
                title: "PR을 달성했습니다!",
                message: "\(prName)에서 개인 최고 기록을 세웠습니다. 꾸준한 노력의 결과입니다!",
                iconName: "medal.fill"
            ))
        }

        // P8: Streak milestone
        if let milestone = input.currentStreakMilestone, milestone > 0 {
            let milestoneText: String
            switch milestone {
            case 7: milestoneText = "1주"
            case 14: milestoneText = "2주"
            case 30: milestoneText = "한 달"
            case 60: milestoneText = "두 달"
            case 90: milestoneText = "세 달"
            case 100: milestoneText = "100일"
            case 365: milestoneText = "1년"
            default: milestoneText = "\(milestone)일"
            }
            results.append(CoachingInsight(
                id: "motivation-streak-\(milestone)",
                priority: .celebration,
                category: .motivation,
                title: "\(milestoneText) 연속 운동!",
                message: "\(milestone)일 연속으로 운동했습니다. 대단한 꾸준함입니다! 이 습관을 계속 이어가세요.",
                iconName: "flame.circle.fill"
            ))
        }

        // P8: Monthly consistency high
        if let streak = input.workoutStreak, streak.monthlyPercentage >= 0.8 {
            results.append(CoachingInsight(
                id: "motivation-monthly-high",
                priority: .celebration,
                category: .motivation,
                title: "이번 달 운동 목표 80% 이상!",
                message: "이번 달 \(streak.monthlyCount)/\(streak.monthlyGoal)일 운동을 달성했습니다. 목표를 완주하세요!",
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
                    title: "데이터를 수집 중입니다",
                    message: "컨디션 점수가 아직 준비되지 않았습니다. 오늘 운동하면 주간 목표에 한 걸음 더 가까워집니다.",
                    iconName: "chart.line.uptrend.xyaxis"
                ))
            } else {
                results.append(CoachingInsight(
                    id: "default-no-score",
                    priority: .fallback,
                    category: .general,
                    title: "데이터를 수집 중입니다",
                    message: "Apple Watch를 착용하고 며칠간 데이터를 수집하면 개인화된 코칭을 받을 수 있습니다.",
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
            title: "오늘도 건강한 하루 되세요",
            message: "꾸준한 운동과 충분한 수면이 최고의 건강 투자입니다.",
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
        if h > 0, m > 0 { return "\(h)시간 \(m)분" }
        if h > 0 { return "\(h)시간" }
        return "\(m)분"
    }
}
