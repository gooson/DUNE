import Foundation

extension HealthQueryService {
    func workoutResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        let load = try await loadWorkouts(in: interval)
        var records = load.records
        if let exerciseID = request.exerciseID, !Self.normalized(exerciseID).isEmpty {
            let target = Self.normalized(exerciseID)
            records = records.filter { Self.normalized($0.exerciseID ?? "") == target || Self.normalized($0.name) == target }
        }
        if !request.workoutIDs.isEmpty {
            let identifiers = Set(request.workoutIDs)
            records = records.filter { identifiers.contains($0.id) || $0.healthKitWorkoutID.map(identifiers.contains) == true }
        }
        if let workoutID = request.workoutID {
            guard let selected = records.first(where: { $0.id == workoutID || $0.healthKitWorkoutID == workoutID }) else {
                return result(request.kind, status: load.complete ? .noData : .unavailable, interval: interval,
                              summary: load.complete
                                ? HealthQueryLocalization.localized("The selected workout is not available in this period.")
                                : HealthQueryLocalization.localized("The selected workout could not be read. Try again later."),
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
                              summary: HealthQueryLocalization.localized("Enter the words to find in your workout notes."))
            }
            records = records.filter { Self.normalized($0.memo).contains(text) }
        }
        guard !records.isEmpty else {
            return result(request.kind, status: load.complete ? .noData : .unavailable, interval: interval,
                          summary: HealthQueryLocalization.localized("No accessible workout records were found in this period."),
                          limitations: load.limitations, isComplete: load.complete)
        }

        switch request.kind {
        case .latestWorkout, .cardioDetail, .strengthSets:
            let latest = records[0]
            let metrics = workoutMetrics(latest)
            let measured = dateText(latest.date)
            let summary = HealthQueryLocalization.localized("\(latest.name), recorded \(measured).") + " " + metricSummary(metrics, includeDates: false)
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
                              summary: HealthQueryLocalization.localized("No completed weighted sets were found for this exercise."))
            }
            let metrics = [
                HealthQueryMetric(id: "weight", title: HealthQueryLocalization.localized("Recorded Weight"), value: best.2, unit: .kilograms, date: best.0.date),
                HealthQueryMetric(id: "reps", title: HealthQueryLocalization.localized("Repetitions"), value: Double(best.1.reps ?? 0), unit: .count, date: best.0.date)
            ]
            let summary = HealthQueryLocalization.localized("\(best.0.name): highest completed set weight in this period.") + " " + metricSummary(metrics)
            var response = workoutResponse(request.kind, interval: interval, load: load, records: [best.0], metrics: metrics, summary: summary)
            response.limitations.append(HealthQueryLocalization.localized("This is actual set weight within the selected period, not an estimated one-repetition maximum."))
            return response
        case .workoutComparison:
            let current = records[0]
            guard let previous = records.dropFirst().first(where: { $0.date < current.date && Self.sameExercise($0, current) }) else {
                return workoutResponse(request.kind, interval: interval, load: load, records: [current],
                                       metrics: workoutMetrics(current), summary: HealthQueryLocalization.localized("No earlier record of the same exercise was found in this period."))
            }
            let metrics = comparisonMetrics(current: current, previous: previous)
            let summary = HealthQueryLocalization.localized("Comparing \(current.name) on \(dateText(current.date)) with \(dateText(previous.date)).") + " " + metricSummary(metrics, includeDates: false)
            return workoutResponse(request.kind, interval: interval, load: load, records: [current, previous], metrics: metrics, summary: summary)
        case .memoSearch:
            let visible = Array(records.prefix(request.limit))
            var limitations = load.limitations
            limitations.append(HealthQueryLocalization.localized("Exact text search of original notes. Semantic search is a separate optional feature."))
            if records.count > request.limit { limitations.append(HealthQueryLocalization.localized("Only the first matching records are displayed.")) }
            return result(request.kind, status: load.complete ? .available : .partial, interval: interval,
                          metrics: [HealthQueryMetric(id: "matches", title: HealthQueryLocalization.localized("Matching Records"), value: Double(records.count), unit: .count)],
                          records: visible, sources: sources(for: visible),
                          summary: HealthQueryLocalization.localized("Found \(records.count) workout notes matching your text in this period."),
                          limitations: limitations, isComplete: load.complete)
        case .workoutSummary, .report:
            let metrics = aggregateMetrics(records)
            let series = dailySeries(records, interval: interval)
            return workoutResponse(request.kind, interval: interval, load: load,
                                   records: Array(records.prefix(request.limit)), metrics: metrics, series: [series],
                                   summary: periodText(interval) + " " + metricSummary(metrics))
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
            limitations.append(HealthQueryLocalization.localized("The shared workout report includes workout statistics only. Body measurements and personal notes are excluded."))
        }
        return result(kind, status: load.complete ? .available : .partial, interval: interval,
                      metrics: metrics, series: series, records: records, sources: sources(for: records),
                      summary: summary, limitations: limitations, isComplete: load.complete)
    }

    func sources(for records: [HealthQueryWorkoutSnapshot]) -> [HealthQuerySource] {
        let fetchedAt = nowProvider()
        return records.prefix(50).flatMap { record in
            [HealthQuerySource(kind: record.source, recordID: record.id, measuredAt: record.date, fetchedAt: fetchedAt)]
                + [record.supplementalHealthKitSource].compactMap { $0 }
        }
    }

    func workoutMetrics(_ record: HealthQueryWorkoutSnapshot) -> [HealthQueryMetric] {
        var metrics: [HealthQueryMetric] = []
        func append(_ id: String, _ title: String, _ value: Double?, _ unit: HealthQueryUnit) {
            guard let value else { return }
            metrics.append(HealthQueryMetric(id: id, title: title, value: value, unit: unit, date: record.date))
        }
        if let weight = record.completedSets.compactMap(\.weightKilograms).filter({ $0 > 0 }).max() {
            append("weight", HealthQueryLocalization.localized("Recorded Weight"), weight, .kilograms)
        }
        append("duration", HealthQueryLocalization.localized("Active Duration"), record.durationSeconds, .seconds)
        append("distance", HealthQueryLocalization.localized("Distance"), record.distanceMeters, .meters)
        let derivedPace: Double? = {
            guard let distance = record.distanceMeters, distance > 0, let seconds = record.durationSeconds else { return nil }
            return Self.valid(seconds / (distance / 1_000), in: 1...86_400)
        }()
        append("pace", HealthQueryLocalization.localized("Average Pace"), record.averagePaceSecondsPerKm ?? derivedPace, .secondsPerKilometer)
        append("heartRate", HealthQueryLocalization.localized("Average Heart Rate"), record.averageHeartRate, .bpm)
        if !record.completedSets.isEmpty {
            append("sets", HealthQueryLocalization.localized("Completed Sets"), Double(record.completedSets.count), .count)
        }
        append("volume", HealthQueryLocalization.localized("Strength Volume"), record.volumeKilogramRepetitions, .kilogramRepetitions)
        append("calories", HealthQueryLocalization.localized("Calories"), record.calories, .kilocalories)
        return metrics
    }

    func aggregateMetrics(_ records: [HealthQueryWorkoutSnapshot]) -> [HealthQueryMetric] {
        var metrics = [HealthQueryMetric(id: "records", title: HealthQueryLocalization.localized("Workout Records"), value: Double(records.count), unit: .count)]
        func sum(_ id: String, _ title: String, _ values: [Double], _ unit: HealthQueryUnit) {
            guard !values.isEmpty else { return }
            let total = values.reduce(0, +)
            guard total.isFinite else { return }
            metrics.append(HealthQueryMetric(id: id, title: title, value: total, unit: unit))
        }
        sum("duration", HealthQueryLocalization.localized("Active Duration"), records.compactMap(\.durationSeconds), .seconds)
        sum("distance", HealthQueryLocalization.localized("Distance"), records.compactMap(\.distanceMeters), .meters)
        sum("calories", HealthQueryLocalization.localized("Calories"), records.compactMap(\.calories), .kilocalories)
        sum("volume", HealthQueryLocalization.localized("Strength Volume"), records.compactMap(\.volumeKilogramRepetitions), .kilogramRepetitions)
        let days = Set(records.map { calendar.startOfDay(for: $0.date) }).count
        metrics.append(HealthQueryMetric(id: "activeDays", title: HealthQueryLocalization.localized("Active Days"), value: Double(days), unit: .count))
        return metrics
    }

    func dailySeries(_ records: [HealthQueryWorkoutSnapshot], interval: DateInterval) -> HealthQuerySeries {
        let grouped = Dictionary(grouping: records, by: { calendar.startOfDay(for: $0.date) })
        // Show observed days only; missing measurements are never represented as zero.
        let points = grouped.keys.sorted().compactMap { date -> HealthQueryPoint? in
            let durations = (grouped[date] ?? []).compactMap(\.durationSeconds)
            guard !durations.isEmpty else { return nil }
            let total = durations.reduce(0, +)
            guard total.isFinite else { return nil }
            return HealthQueryPoint(date: date, value: total)
        }
        return HealthQuerySeries(id: "workoutDuration", title: HealthQueryLocalization.localized("Workout Duration by Day"), unit: .seconds, points: points)
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

    func metricSummary(_ metrics: [HealthQueryMetric], includeDates: Bool = true) -> String {
        var spokenDates: Set<String> = []
        return metrics.prefix(6).map { metric in
            let formatted = formattedMetric(metric)
            var sentence = "\(metric.title): \(formatted)."
            if includeDates, let date = metric.date, spokenDates.insert(dateOnlyText(date)).inserted {
                sentence += " " + HealthQueryLocalization.localized("Record date: \(dateOnlyText(date)).")
            }
            if let previous = metric.comparisonValue {
                let comparison = HealthQueryMetric(id: metric.id, title: metric.title, value: previous,
                                                   unit: metric.unit, date: metric.comparisonDate)
                sentence += " " + HealthQueryLocalization.localized("Previously \(formattedMetric(comparison)).")
                if includeDates, let date = metric.comparisonDate, spokenDates.insert(dateOnlyText(date)).inserted {
                    sentence += " " + HealthQueryLocalization.localized("Comparison date: \(dateOnlyText(date)).")
                }
            }
            return sentence
        }.joined(separator: " ")
    }

    func formattedMetric(_ metric: HealthQueryMetric) -> String {
        let value = metric.value
        switch metric.unit {
        case .count: return number(value)
        case .kilograms: return HealthQueryLocalization.localized("\(number(value, digits: 1)) kilograms")
        case .kilocalories: return HealthQueryLocalization.localized("\(number(value)) kilocalories")
        case .bodyMassIndex: return HealthQueryLocalization.localized("Body mass index \(number(value, digits: 1))")
        case .kilogramRepetitions: return HealthQueryLocalization.localized("\(number(value)) kilogram repetitions")
        case .meters: return HealthQueryLocalization.localized("\(number(value / 1_000, digits: 2)) kilometers")
        case .percent: return HealthQueryLocalization.localized("\(number(value, digits: 1)) percent")
        case .bpm: return HealthQueryLocalization.localized("\(number(value)) beats per minute")
        case .milliseconds: return HealthQueryLocalization.localized("\(number(value)) milliseconds")
        case .score: return HealthQueryLocalization.localized("\(number(value)) out of 100")
        case .seconds:
            if value > 0, value < 1 { return HealthQueryLocalization.localized("Less than one second") }
            let total = Int(value.rounded())
            let hours = total / 3_600
            let minutes = (total % 3_600) / 60
            let seconds = total % 60
            var parts: [String] = []
            if hours > 0 { parts.append(HealthQueryLocalization.localized("\(hours) hours")) }
            if minutes > 0 { parts.append(HealthQueryLocalization.localized("\(minutes) minutes")) }
            if seconds > 0 || parts.isEmpty { parts.append(HealthQueryLocalization.localized("\(seconds) seconds")) }
            return parts.joined(separator: " ")
        case .secondsPerKilometer:
            let seconds = Int(value.rounded())
            return HealthQueryLocalization.localized("\(seconds / 60) minutes \(seconds % 60) seconds per kilometer")
        }
    }
}
