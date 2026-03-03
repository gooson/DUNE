import Foundation

struct LifeAutoWorkoutEntry: Sendable {
    let sourceWorkoutID: String?
    let date: Date
    let activityID: String?
    let exerciseType: String
    let distance: Double?
    let hasSetData: Bool
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let isFromHealthKit: Bool
    let hasHealthKitLink: Bool
}

struct LifeAutoAchievementProgress: Identifiable, Sendable {
    let id: String
    let title: String
    let currentValue: Double
    let targetValue: Double
    let unit: String
    let isCompleted: Bool
    let streakWeeks: Int

    var progressRatio: Double {
        guard targetValue > 0 else { return 0 }
        return Swift.max(0, Swift.min(currentValue / targetValue, 1))
    }

    var progressText: String {
        if unit == "km" {
            let current = currentValue.formatted(.number.precision(.fractionLength(0...1)))
            let target = targetValue.formatted(.number.precision(.fractionLength(0...1)))
            return "\(current) / \(target) km"
        }
        return "\(Int(currentValue))/\(Int(targetValue)) \(unit)"
    }
}

enum LifeAutoAchievementService {
    private enum Rule: String, CaseIterable {
        case weeklyWorkout5
        case weeklyWorkout7
        case weeklyStrength3
        case weeklyChest3
        case weeklyBack3
        case weeklyLowerBody3
        case weeklyShoulders3
        case weeklyArms3
        case weeklyRunning15km

        var title: String {
            switch self {
            case .weeklyWorkout5: "Workout 5x / week"
            case .weeklyWorkout7: "Workout 7x / week"
            case .weeklyStrength3: "Strength 3x / week"
            case .weeklyChest3: "Chest 3x / week"
            case .weeklyBack3: "Back 3x / week"
            case .weeklyLowerBody3: "Lower Body 3x / week"
            case .weeklyShoulders3: "Shoulders 3x / week"
            case .weeklyArms3: "Arms 3x / week"
            case .weeklyRunning15km: "Running 15km / week"
            }
        }

        var target: Double {
            switch self {
            case .weeklyWorkout5:
                return 5
            case .weeklyWorkout7:
                return 7
            case .weeklyRunning15km:
                return 15
            default:
                return 3
            }
        }

        var unit: String {
            switch self {
            case .weeklyRunning15km:
                return "km"
            default:
                return "workouts"
            }
        }

        func currentValue(from metrics: WeekMetrics) -> Double {
            switch self {
            case .weeklyWorkout5:
                return Double(metrics.totalWorkoutCount)
            case .weeklyWorkout7:
                return Double(metrics.totalWorkoutCount)
            case .weeklyStrength3:
                return Double(metrics.strengthWorkoutCount)
            case .weeklyChest3:
                return Double(metrics.strengthBodyAreaCount[.chest] ?? 0)
            case .weeklyBack3:
                return Double(metrics.strengthBodyAreaCount[.back] ?? 0)
            case .weeklyLowerBody3:
                return Double(metrics.strengthBodyAreaCount[.lowerBody] ?? 0)
            case .weeklyShoulders3:
                return Double(metrics.strengthBodyAreaCount[.shoulders] ?? 0)
            case .weeklyArms3:
                return Double(metrics.strengthBodyAreaCount[.arms] ?? 0)
            case .weeklyRunning15km:
                return metrics.runningDistanceKm
            }
        }

        func isCompleted(in metrics: WeekMetrics) -> Bool {
            switch self {
            case .weeklyWorkout5:
                return metrics.totalWorkoutCount >= 5
            case .weeklyWorkout7:
                return metrics.totalWorkoutCount >= 7
            case .weeklyStrength3:
                return metrics.strengthWorkoutCount >= 3
            case .weeklyChest3:
                return (metrics.strengthBodyAreaCount[.chest] ?? 0) >= 3
            case .weeklyBack3:
                return (metrics.strengthBodyAreaCount[.back] ?? 0) >= 3
            case .weeklyLowerBody3:
                return (metrics.strengthBodyAreaCount[.lowerBody] ?? 0) >= 3
            case .weeklyShoulders3:
                return (metrics.strengthBodyAreaCount[.shoulders] ?? 0) >= 3
            case .weeklyArms3:
                return (metrics.strengthBodyAreaCount[.arms] ?? 0) >= 3
            case .weeklyRunning15km:
                return metrics.runningDistanceKm >= 15
            }
        }
    }

    private enum StrengthBodyArea: String, CaseIterable {
        case chest
        case back
        case lowerBody
        case shoulders
        case arms
    }

    private struct WeekMetrics: Sendable {
        var totalWorkoutCount: Int = 0
        var strengthWorkoutCount: Int = 0
        var strengthBodyAreaCount: [StrengthBodyArea: Int] = [:]
        var runningDistanceKm: Double = 0
    }

    static func calculateProgresses(
        from entries: [LifeAutoWorkoutEntry],
        referenceDate: Date = Date()
    ) -> [LifeAutoAchievementProgress] {
        let calendar = mondayStartCalendar()
        let filtered = entries.filter { $0.hasHealthKitLink || $0.isFromHealthKit }
        let workouts = deduplicated(entries: filtered)
        let metricsByWeek = buildMetricsByWeek(from: workouts, calendar: calendar)
        let currentWeekStart = weekStart(for: referenceDate, calendar: calendar)

        return Rule.allCases.map { rule in
            let currentMetrics = metricsByWeek[currentWeekStart] ?? WeekMetrics()
            let currentValue = rule.currentValue(from: currentMetrics)
            return LifeAutoAchievementProgress(
                id: rule.rawValue,
                title: rule.title,
                currentValue: currentValue,
                targetValue: rule.target,
                unit: rule.unit,
                isCompleted: rule.isCompleted(in: currentMetrics),
                streakWeeks: streakWeeks(
                    for: rule,
                    metricsByWeek: metricsByWeek,
                    currentWeekStart: currentWeekStart,
                    calendar: calendar
                )
            )
        }
    }

    // MARK: - Metrics

    private static func buildMetricsByWeek(
        from entries: [LifeAutoWorkoutEntry],
        calendar: Calendar
    ) -> [Date: WeekMetrics] {
        guard !entries.isEmpty else { return [:] }
        var result: [Date: WeekMetrics] = [:]

        for entry in entries {
            let weekKey = weekStart(for: entry.date, calendar: calendar)
            let activityType = resolveActivityType(for: entry)
            let bodyAreas = strengthBodyAreas(for: entry, activityType: activityType)
            let isStrength = isStrengthWorkout(entry, activityType: activityType, bodyAreas: bodyAreas)
            let isRunning = isRunningWorkout(entry, activityType: activityType)

            var metrics = result[weekKey] ?? WeekMetrics()
            metrics.totalWorkoutCount += 1

            if isStrength {
                metrics.strengthWorkoutCount += 1
                for area in bodyAreas {
                    metrics.strengthBodyAreaCount[area, default: 0] += 1
                }
            }

            if isRunning {
                metrics.runningDistanceKm += normalizedDistanceKm(entry.distance)
            }

            result[weekKey] = metrics
        }

        return result
    }

    private static func streakWeeks(
        for rule: Rule,
        metricsByWeek: [Date: WeekMetrics],
        currentWeekStart: Date,
        calendar: Calendar
    ) -> Int {
        var streak = 0
        var cursor = currentWeekStart

        for _ in 0..<260 {
            let metrics = metricsByWeek[cursor] ?? WeekMetrics()
            guard rule.isCompleted(in: metrics) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    // MARK: - Classification

    private static func resolveActivityType(for entry: LifeAutoWorkoutEntry) -> WorkoutActivityType? {
        if let raw = normalizedToken(entry.activityID),
           let resolved = activityType(from: raw) {
            return resolved
        }

        if let raw = normalizedToken(entry.exerciseType),
           let resolved = activityType(from: raw) {
            return resolved
        }

        return nil
    }

    private static func activityType(from raw: String) -> WorkoutActivityType? {
        if let exact = WorkoutActivityType(rawValue: raw) {
            return exact
        }
        if let stem = raw.components(separatedBy: "-").first,
           let stemType = WorkoutActivityType(rawValue: stem) {
            return stemType
        }

        if raw.contains("running") || raw == "run" {
            return .running
        }
        if raw.contains("walking") || raw.contains("walk") {
            return .walking
        }
        if raw.contains("cycling") || raw.contains("bike") {
            return .cycling
        }
        if raw.contains("strength") || raw.contains("weight") {
            return .traditionalStrengthTraining
        }
        return nil
    }

    private static func isStrengthWorkout(
        _ entry: LifeAutoWorkoutEntry,
        activityType: WorkoutActivityType?,
        bodyAreas: Set<StrengthBodyArea>
    ) -> Bool {
        if entry.hasSetData { return true }
        if let activityType, activityType.category == .strength { return true }
        if !bodyAreas.isEmpty, let activityType {
            return activityType.category == .strength
        }
        let lowered = entry.exerciseType.lowercased()
        return lowered.contains("strength")
            || lowered.contains("weight")
            || lowered.contains("bench")
            || lowered.contains("squat")
            || lowered.contains("deadlift")
            || lowered.contains("press")
    }

    private static func strengthBodyAreas(
        for entry: LifeAutoWorkoutEntry,
        activityType: WorkoutActivityType?
    ) -> Set<StrengthBodyArea> {
        let musclesFromRecord = entry.primaryMuscles + entry.secondaryMuscles
        let muscles = musclesFromRecord.isEmpty ? (activityType?.primaryMuscles ?? []) : musclesFromRecord
        guard !muscles.isEmpty else { return [] }

        var areas: Set<StrengthBodyArea> = []
        for muscle in muscles {
            switch muscle {
            case .chest:
                areas.insert(.chest)
            case .back, .lats, .traps:
                areas.insert(.back)
            case .quadriceps, .hamstrings, .glutes, .calves:
                areas.insert(.lowerBody)
            case .shoulders:
                areas.insert(.shoulders)
            case .biceps, .triceps, .forearms:
                areas.insert(.arms)
            case .core:
                continue
            }
        }
        return areas
    }

    private static func isRunningWorkout(
        _ entry: LifeAutoWorkoutEntry,
        activityType: WorkoutActivityType?
    ) -> Bool {
        if activityType == .running { return true }
        let lowered = entry.exerciseType.lowercased()
        return lowered.contains("running") || lowered.contains("run")
    }

    // MARK: - Normalization

    private static func normalizedDistanceKm(_ rawDistance: Double?) -> Double {
        guard let distance = rawDistance, distance.isFinite, distance > 0 else { return 0 }
        // Guard against meter-stored values from imported records.
        if distance > 300 {
            return distance / 1_000
        }
        return distance
    }

    private static func normalizedToken(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private static func deduplicated(entries: [LifeAutoWorkoutEntry]) -> [LifeAutoWorkoutEntry] {
        guard !entries.isEmpty else { return [] }
        var seen: Set<String> = []
        var results: [LifeAutoWorkoutEntry] = []
        results.reserveCapacity(entries.count)

        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let key = dedupKey(for: entry)
            if seen.insert(key).inserted {
                results.append(entry)
            }
        }
        return results
    }

    private static func dedupKey(for entry: LifeAutoWorkoutEntry) -> String {
        if let id = normalizedToken(entry.sourceWorkoutID) {
            return "hk:\(id)"
        }
        let timestamp = Int(entry.date.timeIntervalSinceReferenceDate.rounded())
        let type = normalizedToken(entry.activityID) ?? normalizedToken(entry.exerciseType) ?? "unknown"
        return "local:\(timestamp):\(type)"
    }

    private static func mondayStartCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        calendar.locale = Calendar.current.locale
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
