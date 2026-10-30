import Foundation

extension HealthQueryService {
    func comparisonResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        let previous = request.comparisonInterval ?? DateInterval(
            start: interval.start.addingTimeInterval(-interval.duration), end: interval.start
        )
        guard previous.start.timeIntervalSinceReferenceDate.isFinite,
              previous.end.timeIntervalSinceReferenceDate.isFinite,
              previous.duration > 0, previous.duration <= 367 * 86_400,
              previous.end <= nowProvider().addingTimeInterval(1) else {
            return result(request.kind, status: .invalidRequest, interval: interval,
                          summary: String(localized: "Choose a valid comparison period of up to one year."))
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
                metric.comparisonDate = previous.end
            }
            return metric
        }
        if let current = currentSleep.metrics.first(where: { $0.id == "sleepAverage" }) {
            var sleep = current
            sleep.comparisonValue = priorSleep.metrics.first(where: { $0.id == "sleepAverage" })?.value
            sleep.comparisonDate = sleep.comparisonValue == nil ? nil : previous.end
            metrics.append(sleep)
        }
        let complete = currentWorkouts.complete && priorWorkouts.complete && currentSleep.isComplete && priorSleep.isComplete
        let hasRecords = !currentWorkouts.records.isEmpty || !priorWorkouts.records.isEmpty || !currentSleep.metrics.isEmpty || !priorSleep.metrics.isEmpty
        var limitations = currentWorkouts.limitations + priorWorkouts.limitations + currentSleep.limitations + priorSleep.limitations
        limitations.append(String(localized: "The comparison describes recorded activity and sleep. It does not establish that one caused the other."))
        if abs(interval.duration - previous.duration) > 60 {
            limitations.append(String(localized: "These periods have different lengths. Totals are not normalized by day."))
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
                      interval: interval, metrics: metrics,
                      series: [dailySeries(currentWorkouts.records, interval: interval)] + currentSleep.series,
                      records: Array(currentWorkouts.records.prefix(request.limit)),
                      sources: sources(for: currentWorkouts.records + priorWorkouts.records) + currentSleep.sources + priorSleep.sources,
                      summary: String(localized: "Comparing \(dateText(interval.start)) through \(dateText(interval.end)) with \(dateText(previous.start)) through \(dateText(previous.end)).") + " " + metricSummary(metrics),
                      limitations: Array(Set(limitations)).sorted(), isComplete: complete)
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
                      summary: String(localized: "Recorded health information from \(dateText(interval.start)) through \(dateText(interval.end)).") + " " + metricSummary(metrics),
                      limitations: Array(Set(results.flatMap(\.limitations) + [String(localized: "This summary uses available records and does not provide a medical diagnosis.")])).sorted(),
                      isComplete: complete)
    }
}
