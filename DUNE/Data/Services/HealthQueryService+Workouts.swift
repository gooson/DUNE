import Foundation

extension HealthQueryService {
    func workoutResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        let load = try await loadWorkouts(in: interval)
        var records = load.records
        if let exerciseID = request.exerciseID, !Self.normalized(exerciseID).isEmpty {
            let target = Self.normalized(exerciseID)
            records = records.filter { Self.normalized($0.exerciseID ?? "") == target || Self.normalized($0.name) == target }
        }
        if let workoutID = request.workoutID {
            guard let selected = records.first(where: { $0.id == workoutID || $0.healthKitWorkoutID == workoutID }) else {
                return result(request.kind, status: .noData, interval: interval,
                              summary: String(localized: "The selected workout is not available in this period."),
                              limitations: load.limitations, isComplete: load.complete)
            }
            if request.kind == .workoutComparison {
                records = [selected] + records.filter { $0.id != selected.id && $0.date < selected.date && Self.sameExercise($0, selected) }
            } else {
                records = [selected]
            }
        }
        if request.kind == .cardioDetail {
            records = records.filter { record in
                guard let activity = record.activityType else { return false }
                return activity.category != .strength && (activity.isDistanceBased || activity.category == .cardio)
            }
        }
        if request.kind == .strengthSets || request.kind == .personalRecord {
            records = records.filter { !$0.completedSets.isEmpty }
        }
        if request.kind == .memoSearch {
            let text = Self.normalized(request.searchText ?? "")
            guard !text.isEmpty else {
                return result(request.kind, status: .invalidRequest, interval: interval,
                              summary: String(localized: "Enter the words to find in your workout notes."))
            }
            records = records.filter { Self.normalized($0.memo).contains(text) }
        }
        guard !records.isEmpty else {
            return result(request.kind, status: load.complete ? .noData : .unavailable, interval: interval,
                          summary: String(localized: "No accessible workout records were found in this period."),
                          limitations: load.limitations, isComplete: load.complete)
        }

        switch request.kind {
        case .latestWorkout, .cardioDetail, .strengthSets:
            let latest = records[0]
            let metrics = workoutMetrics(latest)
            let measured = dateText(latest.date)
            let summary = String(localized: "\(latest.name), recorded \(measured).") + " " + metricSummary(metrics)
            return workoutResponse(request.kind, interval: interval, load: load, records: [latest], metrics: metrics, summary: summary)
        case .personalRecord:
            let latest = records[0]
            // An unspecified exercise refers to the most recently recorded strength exercise.
            let exercise = records.filter { Self.sameExercise($0, latest) }
            let candidates = exercise.flatMap { record in
                record.completedSets.compactMap { set -> (HealthQueryWorkoutSnapshot, HealthQuerySetSnapshot, Double)? in
                    guard let weight = Self.valid(set.weightKilograms, in: 0.001...500),
                          let reps = set.reps, (1...100).contains(reps) else { return nil }
                    return (record, set, weight)
                }
            }
            guard let best = candidates.max(by: { $0.2 < $1.2 }) else {
                return result(request.kind, status: .noData, interval: interval,
                              summary: String(localized: "No completed weighted sets were found for this exercise."))
            }
            let metrics = [
                HealthQueryMetric(id: "weight", title: String(localized: "Recorded Weight"), value: best.2, unit: .kilograms, date: best.0.date),
                HealthQueryMetric(id: "reps", title: String(localized: "Repetitions"), value: Double(best.1.reps ?? 0), unit: .count, date: best.0.date)
            ]
            let summary = String(localized: "\(best.0.name): highest completed set weight in this period.") + " " + metricSummary(metrics)
            var response = workoutResponse(request.kind, interval: interval, load: load, records: [best.0], metrics: metrics, summary: summary)
            response.limitations.append(String(localized: "This is actual set weight within the selected period, not an estimated one-repetition maximum."))
            return response
        case .workoutComparison:
            let current = records[0]
            guard let previous = records.dropFirst().first(where: { $0.date < current.date && Self.sameExercise($0, current) }) else {
                return workoutResponse(request.kind, interval: interval, load: load, records: [current],
                                       metrics: workoutMetrics(current), summary: String(localized: "No earlier record of the same exercise was found in this period."))
            }
            let metrics = comparisonMetrics(current: current, previous: previous)
            let summary = String(localized: "Comparing \(current.name) on \(dateText(current.date)) with \(dateText(previous.date)).") + " " + metricSummary(metrics)
            return workoutResponse(request.kind, interval: interval, load: load, records: [current, previous], metrics: metrics, summary: summary)
        case .memoSearch:
            let visible = Array(records.prefix(request.limit))
            var limitations = load.limitations
            limitations.append(String(localized: "Exact text search of original notes. Semantic search is a separate optional feature."))
            if records.count > request.limit { limitations.append(String(localized: "Only the first matching records are displayed.")) }
            return result(request.kind, status: load.complete ? .available : .partial, interval: interval,
                          metrics: [HealthQueryMetric(id: "matches", title: String(localized: "Matching Records"), value: Double(records.count), unit: .count)],
                          records: visible, sources: sources(for: visible),
                          summary: String(localized: "Found \(records.count) workout notes matching your text in this period."),
                          limitations: limitations, isComplete: load.complete)
        case .workoutSummary, .report:
            let metrics = aggregateMetrics(records)
            let series = dailySeries(records, interval: interval)
            return workoutResponse(request.kind, interval: interval, load: load,
                                   records: Array(records.prefix(request.limit)), metrics: metrics, series: [series],
                                   summary: String(localized: "From \(dateText(interval.start)) through \(dateText(interval.end)).") + " " + metricSummary(metrics))
        case .latestBody, .bodyTrend, .sleep, .condition, .metricComparison, .longAnalysis:
            throw HealthQueryServiceError.notConfigured
        }
    }

    func workoutResponse(
        _ kind: HealthQueryKind, interval: DateInterval, load: WorkoutLoad,
        records: [HealthQueryWorkoutSnapshot], metrics: [HealthQueryMetric],
        series: [HealthQuerySeries] = [], summary: String
    ) -> HealthQueryResult {
        var limitations = load.limitations
        if kind == .report {
            limitations.append(String(localized: "The shared workout report includes workout statistics only. Body measurements and personal notes are excluded."))
        }
        return result(kind, status: load.complete ? .available : .partial, interval: interval,
                      metrics: metrics, series: series, records: records, sources: sources(for: records),
                      summary: summary, limitations: limitations, isComplete: load.complete)
    }

    func sources(for records: [HealthQueryWorkoutSnapshot]) -> [HealthQuerySource] {
        records.prefix(50).map { HealthQuerySource(kind: $0.source, recordID: $0.id, measuredAt: $0.date, fetchedAt: nowProvider()) }
    }

    func workoutMetrics(_ record: HealthQueryWorkoutSnapshot) -> [HealthQueryMetric] {
        var metrics: [HealthQueryMetric] = []
        func append(_ id: String, _ title: String, _ value: Double?, _ unit: HealthQueryUnit) {
            guard let value else { return }
            metrics.append(HealthQueryMetric(id: id, title: title, value: value, unit: unit, date: record.date))
        }
        if let weight = record.completedSets.compactMap(\.weightKilograms).filter({ $0 > 0 }).max() {
            append("weight", String(localized: "Recorded Weight"), weight, .kilograms)
        }
        append("duration", String(localized: "Active Duration"), record.durationSeconds, .seconds)
        append("distance", String(localized: "Distance"), record.distanceMeters, .meters)
        let derivedPace: Double? = {
            guard let distance = record.distanceMeters, distance > 0, let seconds = record.durationSeconds else { return nil }
            return Self.valid(seconds / (distance / 1_000), in: 1...86_400)
        }()
        append("pace", String(localized: "Average Pace"), record.averagePaceSecondsPerKm ?? derivedPace, .secondsPerKilometer)
        append("heartRate", String(localized: "Average Heart Rate"), record.averageHeartRate, .bpm)
        if !record.completedSets.isEmpty {
            append("sets", String(localized: "Completed Sets"), Double(record.completedSets.count), .count)
        }
        append("volume", String(localized: "Strength Volume"), record.volumeKilogramRepetitions, .kilogramRepetitions)
        append("calories", String(localized: "Calories"), record.calories, .kilocalories)
        return metrics
    }

    func aggregateMetrics(_ records: [HealthQueryWorkoutSnapshot]) -> [HealthQueryMetric] {
        var metrics = [HealthQueryMetric(id: "records", title: String(localized: "Workout Records"), value: Double(records.count), unit: .count)]
        func sum(_ id: String, _ title: String, _ values: [Double], _ unit: HealthQueryUnit) {
            guard !values.isEmpty else { return }
            let total = values.reduce(0, +)
            guard total.isFinite else { return }
            metrics.append(HealthQueryMetric(id: id, title: title, value: total, unit: unit))
        }
        sum("duration", String(localized: "Active Duration"), records.compactMap(\.durationSeconds), .seconds)
        sum("distance", String(localized: "Distance"), records.compactMap(\.distanceMeters), .meters)
        sum("calories", String(localized: "Calories"), records.compactMap(\.calories), .kilocalories)
        sum("volume", String(localized: "Strength Volume"), records.compactMap(\.volumeKilogramRepetitions), .kilogramRepetitions)
        let days = Set(records.map { calendar.startOfDay(for: $0.date) }).count
        metrics.append(HealthQueryMetric(id: "activeDays", title: String(localized: "Active Days"), value: Double(days), unit: .count))
        return metrics
    }

    func dailySeries(_ records: [HealthQueryWorkoutSnapshot], interval: DateInterval) -> HealthQuerySeries {
        let grouped = Dictionary(grouping: records, by: { calendar.startOfDay(for: $0.date) })
        // Show observed days only; missing measurements are never represented as zero.
        let points = grouped.keys.sorted().map { date in
            HealthQueryPoint(date: date, value: (grouped[date] ?? []).compactMap(\.durationSeconds).reduce(0, +))
        }
        return HealthQuerySeries(id: "workoutDuration", title: String(localized: "Workout Duration by Day"), unit: .seconds, points: points)
    }

    static func sameExercise(_ first: HealthQueryWorkoutSnapshot, _ second: HealthQueryWorkoutSnapshot) -> Bool {
        if let firstID = first.exerciseID, !firstID.isEmpty, let secondID = second.exerciseID, !secondID.isEmpty {
            return firstID == secondID
        }
        return !normalized(first.name).isEmpty && normalized(first.name) == normalized(second.name)
    }

    func comparisonMetrics(current: HealthQueryWorkoutSnapshot, previous: HealthQueryWorkoutSnapshot) -> [HealthQueryMetric] {
        let previousMetrics = workoutMetrics(previous)
        return workoutMetrics(current).map { metric in
            var metric = metric
            if let previousMetric = previousMetrics.first(where: { $0.id == metric.id && $0.unit == metric.unit }) {
                metric.comparisonValue = previousMetric.value
                metric.comparisonDate = previous.date
            }
            return metric
        }
    }

    func metricSummary(_ metrics: [HealthQueryMetric]) -> String {
        metrics.prefix(6).map { metric in
            let formatted = formattedMetric(metric)
            let date = metric.date.map { " · " + dateText($0) } ?? ""
            var sentence = "\(metric.title): \(formatted)\(date)."
            if let previous = metric.comparisonValue {
                var comparison = metric
                comparison.value = previous
                sentence += " " + String(localized: "Previously \(formattedMetric(comparison)).")
            }
            return sentence
        }.joined(separator: " ")
    }

    func formattedMetric(_ metric: HealthQueryMetric) -> String {
        let value = metric.value
        switch metric.unit {
        case .count: return number(value)
        case .kilograms: return String(localized: "\(number(value, digits: 1)) kilograms")
        case .kilocalories: return String(localized: "\(number(value)) kilocalories")
        case .bodyMassIndex: return String(localized: "Body mass index \(number(value, digits: 1))")
        case .kilogramRepetitions: return String(localized: "\(number(value)) kilogram repetitions")
        case .meters: return String(localized: "\(number(value / 1_000, digits: 2)) kilometers")
        case .percent: return String(localized: "\(number(value, digits: 1)) percent")
        case .bpm: return String(localized: "\(number(value)) beats per minute")
        case .milliseconds: return String(localized: "\(number(value)) milliseconds")
        case .score: return String(localized: "\(number(value)) out of 100")
        case .seconds:
            let minutes = Int((value / 60).rounded())
            return String(localized: "\(minutes) minutes")
        case .secondsPerKilometer:
            let seconds = Int(value.rounded())
            return String(localized: "\(seconds / 60) minutes \(seconds % 60) seconds per kilometer")
        }
    }
}
