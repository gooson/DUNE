import Foundation

#if DEBUG
/// Opt-in synthetic records for native UI evidence. Nothing is written to the app store or HealthKit.
@MainActor
struct HealthQueryUITestFixture: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        let interval = request.interval ?? HealthQueryPeriod.last30Days.interval(endingAt: Date())
        let now = interval.end
        let prior = interval.start.addingTimeInterval(interval.duration * 0.2)
        let middle = interval.start.addingTimeInterval(interval.duration * 0.5)
        let recent = interval.start.addingTimeInterval(interval.duration * 0.8)
        let comparisonDate = interval.start.addingTimeInterval(-interval.duration * 0.5)
        let kind = request.kind
        if ProcessInfo.processInfo.arguments.contains("--ui-health-query-no-data") {
            return HealthQueryResult(kind: kind, status: .noData, title: HealthQueryService.title(for: kind),
                                     generatedAt: now, interval: interval, spokenSummary: "No synthetic records.")
        }

        func m(_ id: String, _ title: String, _ value: Double, _ unit: HealthQueryUnit,
               _ date: Date? = nil, _ old: Double? = nil, _ oldDate: Date? = nil) -> HealthQueryMetric {
            HealthQueryMetric(id: id, title: title, value: value, unit: unit, date: date,
                              comparisonValue: old, comparisonDate: oldDate)
        }
        func chart(_ id: String, _ title: String, _ unit: HealthQueryUnit,
                   _ values: [(Date, Double)]) -> HealthQuerySeries {
            HealthQuerySeries(id: id, title: title, unit: unit,
                              points: values.map { HealthQueryPoint(date: $0.0, value: $0.1) })
        }
        let previousStrength = HealthQueryWorkoutSnapshot(
            id: "sample-strength-prior", exerciseID: "sample-bench", name: "Sample bench press",
            date: prior, durationSeconds: 2_400, calories: 180,
            completedSets: [HealthQuerySetSnapshot(id: "sample-set-prior", number: 1, weightKilograms: 35, reps: 8)],
            memo: "Sample prior workout note", source: .app)
        let cardio = HealthQueryWorkoutSnapshot(
            id: "sample-cardio", name: "Sample outdoor run", date: middle, durationSeconds: 1_800,
            distanceMeters: 5_000, averagePaceSecondsPerKm: 360, averageHeartRate: 142,
            calories: 300, source: .app)
        let currentStrength = HealthQueryWorkoutSnapshot(
            id: "sample-strength-current", exerciseID: "sample-bench", name: "Sample bench press",
            date: recent, durationSeconds: 2_700, calories: 210,
            completedSets: [HealthQuerySetSnapshot(id: "sample-set-current", number: 1, weightKilograms: 40, reps: 8)],
            memo: "Sample current workout note", source: .app)
        let workouts = [currentStrength, cardio, previousStrength]
        let workoutSources = workouts.map {
            HealthQuerySource(kind: .app, recordID: $0.id, measuredAt: $0.date, fetchedAt: now)
        }
        let healthSources = [prior, recent].map {
            HealthQuerySource(kind: .healthKit, measuredAt: $0, fetchedAt: now)
        }
        let totals = [
            m("records", "Workout Records", 3, .count),
            m("duration", "Active Duration", 6_900, .seconds),
            m("distance", "Distance", 5_000, .meters),
            m("calories", "Calories", 690, .kilocalories),
            m("volume", "Strength Volume", 600, .kilogramRepetitions),
            m("activeDays", "Active Days", 3, .count)
        ]
        let body = [
            m("weight", "Weight", 68.4, .kilograms, recent,
              kind == .bodyTrend ? 69.2 : nil, kind == .bodyTrend ? prior : nil),
            m("bodyFat", "Body Fat", 21.4, .percent, recent),
            m("bmi", "BMI", 22.3, .bodyMassIndex, recent)
        ]
        let sleep = [
            m("sleepTotal", "Total Sleep", 55_800, .seconds),
            m("sleepAverage", "Average Recorded Sleep", 27_900, .seconds),
            m("recordedNights", "Recorded Nights", 2, .count),
            m("sleep-deep", "Deep Sleep", 13_200, .seconds),
            m("sleep-rem", "REM Sleep", 18_000, .seconds),
            m("sleep-core", "Core Sleep", 24_600, .seconds)
        ]
        let workoutChart = chart("workoutDuration", "Workout Duration by Day", .seconds,
                                 [(prior, 2_400), (middle, 1_800), (recent, 2_700)])
        let sleepChart = chart("sleep", "Sleep", .seconds, [(prior, 27_000), (recent, 28_800)])
        let bodyChart = chart("weight", "Weight", .kilograms, [(prior, 69.2), (recent, 68.4)])
        var metrics: [HealthQueryMetric] = []
        var series: [HealthQuerySeries] = []
        var records: [HealthQueryWorkoutSnapshot] = []
        var sources: [HealthQuerySource] = []
        var limitations = ["Synthetic UI test records; these are not personal health data."]
        var summary = "Synthetic UI test records."

        switch kind {
        case .latestWorkout:
            metrics = [m("weight", "Recorded Weight", 40, .kilograms, recent),
                       m("duration", "Active Duration", 2_700, .seconds, recent),
                       m("sets", "Completed Sets", 1, .count, recent),
                       m("volume", "Strength Volume", 320, .kilogramRepetitions, recent),
                       m("calories", "Calories", 210, .kilocalories, recent)]
            records = [currentStrength]; sources = [workoutSources[0]]
        case .workoutSummary:
            metrics = totals; series = [workoutChart]; records = workouts; sources = workoutSources
        case .strengthSets:
            metrics = [m("weight", "Recorded Weight", 40, .kilograms, recent),
                       m("sets", "Completed Sets", 1, .count, recent),
                       m("volume", "Strength Volume", 320, .kilogramRepetitions, recent)]
            records = [currentStrength]; sources = [workoutSources[0]]
        case .personalRecord:
            metrics = [m("weight", "Recorded Weight", 40, .kilograms, recent),
                       m("reps", "Repetitions", 8, .count, recent)]
            records = [currentStrength]; sources = [workoutSources[0]]
        case .cardioDetail:
            metrics = [m("duration", "Active Duration", 1_800, .seconds, middle),
                       m("distance", "Distance", 5_000, .meters, middle),
                       m("pace", "Average Pace", 360, .secondsPerKilometer, middle),
                       m("heartRate", "Average Heart Rate", 142, .bpm, middle),
                       m("calories", "Calories", 300, .kilocalories, middle)]
            records = [cardio]; sources = [workoutSources[1]]
        case .latestBody:
            metrics = body; sources = [healthSources[1]]
        case .bodyTrend:
            metrics = body; series = [bodyChart]; sources = healthSources
        case .sleep:
            metrics = sleep; series = [sleepChart]; sources = healthSources
        case .condition:
            metrics = [m("condition", "Condition Score", 82, .score, recent),
                       m("hrv", "Heart Rate Variability", 48, .milliseconds, recent),
                       m("restingHeartRate", "Resting Heart Rate", 59, .bpm, recent)]
            series = [chart("condition", "Condition Score", .score, [(prior, 77), (recent, 82)])]
            sources = [HealthQuerySource(kind: .calculated, measuredAt: recent, fetchedAt: now)] + healthSources
        case .metricComparison:
            metrics = [m("records", "Workout Records", 3, .count, recent, 2, comparisonDate),
                       m("duration", "Active Duration", 6_900, .seconds, recent, 4_200, comparisonDate),
                       m("sleepAverage", "Average Recorded Sleep", 27_900, .seconds, recent, 26_400, comparisonDate)]
            series = [workoutChart, sleepChart]; records = workouts
            sources = workoutSources + healthSources
                + [HealthQuerySource(kind: .app, measuredAt: comparisonDate, fetchedAt: now),
                   HealthQuerySource(kind: .healthKit, measuredAt: comparisonDate, fetchedAt: now)]
            limitations.append("The comparison does not establish causation.")
        case .workoutComparison:
            metrics = [m("weight", "Recorded Weight", 40, .kilograms, recent, 35, prior),
                       m("duration", "Active Duration", 2_700, .seconds, recent, 2_400, prior),
                       m("volume", "Strength Volume", 320, .kilogramRepetitions, recent, 280, prior)]
            records = [currentStrength, previousStrength]; sources = [workoutSources[0], workoutSources[2]]
        case .memoSearch:
            guard request.searchText?.localizedCaseInsensitiveContains("sample") == true else {
                return HealthQueryResult(kind: kind, status: .noData, title: HealthQueryService.title(for: kind),
                                         generatedAt: now, interval: interval, spokenSummary: "No matching synthetic notes.")
            }
            metrics = [m("matches", "Matching Records", 1, .count)]
            records = [currentStrength]; sources = [workoutSources[0]]
            summary = "One synthetic note matches the search."
        case .report:
            metrics = totals; series = [workoutChart]; records = workouts; sources = workoutSources
            limitations.append("The shared report excludes body measurements and personal notes.")
        case .longAnalysis:
            metrics = totals + sleep + body; series = [workoutChart, sleepChart, bodyChart]
            records = workouts; sources = workoutSources + healthSources
            limitations.append("This summary is not a medical diagnosis.")
        }
        return HealthQueryResult(kind: kind, status: .available, title: HealthQueryService.title(for: kind),
                                 generatedAt: now, interval: interval, metrics: metrics, series: series,
                                 records: records, sources: sources, spokenSummary: summary,
                                 explanation: kind == .longAnalysis ? "Synthetic activity, sleep, and body trends." : nil,
                                 limitations: limitations)
    }
}
#endif
