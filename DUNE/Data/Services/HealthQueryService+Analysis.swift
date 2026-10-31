import Foundation

extension HealthQueryService {
    func comparisonResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        let previous = request.comparisonInterval ?? previousComparisonInterval(for: interval)
        guard previous.start.timeIntervalSinceReferenceDate.isFinite,
              previous.end.timeIntervalSinceReferenceDate.isFinite,
              previous.duration > 0, previous.duration <= 367 * 86_400,
              previous.end <= nowProvider().addingTimeInterval(1) else {
            return result(request.kind, status: .invalidRequest, interval: interval,
                          summary: HealthQueryLocalization.localized("Choose a valid comparison period of up to one year."))
        }
        let currentWorkouts = try await loadWorkouts(in: interval)
        try Task.checkCancellation()
        let priorWorkouts = try await loadWorkouts(in: previous)
        let currentSleep = try await sleepResult(HealthQueryRequest(kind: .sleep), interval: interval)
        let priorSleep = try await sleepResult(HealthQueryRequest(kind: .sleep), interval: previous)
        var metrics = aggregateMetrics(currentWorkouts.records)
        let priorMetrics = aggregateMetrics(priorWorkouts.records)
        metrics = metrics.map { metric in
            var metric = metric
            if let old = priorMetrics.first(where: { $0.id == metric.id && $0.unit == metric.unit }) {
                metric.comparisonValue = old.value
            }
            return metric
        }
        if let current = currentSleep.metrics.first(where: { $0.id == "sleepAverage" }) {
            var sleep = current
            sleep.comparisonValue = priorSleep.metrics.first(where: { $0.id == "sleepAverage" })?.value
            // A period average remains an aggregate even when only one night was recorded.
            sleep.date = nil
            metrics.append(sleep)
        }
        let complete = currentWorkouts.complete && priorWorkouts.complete && currentSleep.isComplete && priorSleep.isComplete
        let hasRecords = !currentWorkouts.records.isEmpty || !priorWorkouts.records.isEmpty || !currentSleep.metrics.isEmpty || !priorSleep.metrics.isEmpty
        var limitations = currentWorkouts.limitations + priorWorkouts.limitations + currentSleep.limitations + priorSleep.limitations
        limitations.append(HealthQueryLocalization.localized("The comparison describes recorded activity and sleep. It does not establish that one caused the other."))
        if abs(interval.duration - previous.duration) > 0.001 {
            limitations.append(HealthQueryLocalization.localized("These periods have different lengths. Totals are not normalized by day."))
        }
        if !complete {
            // A missing source cannot support an apparent zero or an exact period delta.
            metrics = metrics.filter { $0.value != 0 }.map { metric in
                var metric = metric
                metric.comparisonValue = nil
                metric.comparisonDate = nil
                return metric
            }
        }
        return result(request.kind, status: hasRecords ? (complete ? .available : .partial) : (complete ? .noData : .unavailable),
                      interval: interval, comparisonInterval: previous, metrics: metrics,
                      series: [dailySeries(currentWorkouts.records, interval: interval)] + currentSleep.series,
                      records: Array(currentWorkouts.records.prefix(request.limit)),
                      sources: sources(for: currentWorkouts.records + priorWorkouts.records) + currentSleep.sources + priorSleep.sources,
                      summary: HealthQueryLocalization.localized("Comparing \(dateOnlyText(interval.start)) through \(dateOnlyText(interval.end.addingTimeInterval(-0.001))) with \(dateOnlyText(previous.start)) through \(dateOnlyText(previous.end.addingTimeInterval(-0.001))).") + " " + metricSummary(metrics),
                      limitations: Array(Set(limitations)).sorted(), isComplete: complete)
    }

    func previousComparisonInterval(for interval: DateInterval) -> DateInterval {
        guard calendar.startOfDay(for: interval.start) == interval.start else {
            return DateInterval(start: interval.start.addingTimeInterval(-interval.duration), end: interval.start)
        }
        let endDay = calendar.startOfDay(for: interval.end)
        let fullDays = calendar.dateComponents([.day], from: interval.start, to: endDay).day ?? 0
        let days = max(1, fullDays + (interval.end > endDay ? 1 : 0))
        let start = calendar.date(byAdding: .day, value: -days, to: interval.start) ?? interval.start
        return DateInterval(start: start, end: interval.start)
    }

    func analysisResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        let workouts = try await workoutResult(HealthQueryRequest(kind: .workoutSummary, limit: request.limit), interval: interval)
        try Task.checkCancellation()
        let sleep = try await sleepResult(HealthQueryRequest(kind: .sleep), interval: interval)
        let body = try await bodyResult(HealthQueryRequest(kind: .bodyTrend), interval: interval)
        let results = [workouts, sleep, body]
        let metrics = results.flatMap(\.metrics)
        let complete = results.allSatisfy(\.isComplete)
        let available = !metrics.isEmpty
        return result(request.kind, status: available ? (complete ? .available : .partial) : (complete ? .noData : .unavailable),
                      interval: interval, metrics: metrics, series: results.flatMap(\.series), records: workouts.records,
                      sources: results.flatMap(\.sources),
                      summary: periodText(interval) + " " + metricSummary(metrics),
                      limitations: Array(Set(results.flatMap(\.limitations) + [HealthQueryLocalization.localized("This summary uses available records and does not provide a medical diagnosis.")])).sorted(),
                      isComplete: complete)
    }
}
