import Foundation

/// Synthetic UI evidence only. This route is unavailable in release builds.
enum HealthQueryServiceRouting {
    @MainActor static func current() -> any HealthQuerying {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitesting"), args.contains("--ui-health-query-fixture") {
            return HealthQueryUITestFixture()
        }
        #endif
        return HealthQueryService.shared
    }
}

#if DEBUG
@MainActor
private struct HealthQueryUITestFixture: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        let interval = request.interval ?? HealthQueryPeriod.last30Days.interval(endingAt: Date())
        let now = interval.end
        let recordDate = interval.start.addingTimeInterval(interval.duration * 0.75)
        let empty = ProcessInfo.processInfo.arguments.contains("--ui-health-query-no-data")
        let kind = request.kind
        if empty {
            return HealthQueryResult(kind: kind, status: .noData, title: HealthQueryService.title(for: kind),
                                     generatedAt: now, interval: interval, spokenSummary: "No fixture records.")
        }
        let workout = HealthQueryWorkoutSnapshot(
            id: "ui-fixture-workout", name: "Sample strength workout", date: recordDate,
            durationSeconds: 2_700,
            completedSets: [HealthQuerySetSnapshot(id: "sample-set-1", number: 1, weightKilograms: 40, reps: 8)],
            memo: "Sample workout note", source: .app
        )
        let metric = HealthQueryMetric(id: "sample-metric", title: metricTitle(for: kind),
                                       value: metricValue(for: kind), unit: metricUnit(for: kind),
                                       date: recordDate, comparisonValue: 32)
        let points = (0..<5).map { index in
            HealthQueryPoint(date: interval.start.addingTimeInterval(interval.duration * Double(index + 1) / 6),
                             value: metric.value + Double(index - 2))
        }
        let series = HealthQuerySeries(id: "sample-trend", title: "Sample trend", unit: metric.unit, points: points)
        let records: [HealthQueryWorkoutSnapshot] = switch kind {
        case .latestWorkout, .strengthSets, .cardioDetail, .workoutComparison, .memoSearch, .report, .longAnalysis:
            [workout]
        default: []
        }
        return HealthQueryResult(
            kind: kind, status: .available, title: HealthQueryService.title(for: kind),
            generatedAt: now, interval: interval, metrics: [metric], series: [series], records: records,
            sources: [HealthQuerySource(kind: .app, recordID: "ui-fixture-workout", measuredAt: workout.date,
                                        fetchedAt: now)],
            spokenSummary: "Sample result for UI testing.",
            explanation: kind == .longAnalysis ? "Sample analysis from synthetic records." : nil,
            limitations: ["Synthetic UI test records"], isComplete: true
        )
    }

    private func metricTitle(for kind: HealthQueryKind) -> String {
        switch kind {
        case .sleep: "Sleep duration"
        case .condition: "Condition score"
        case .latestBody, .bodyTrend: "Body weight"
        case .personalRecord: "Highest weight"
        case .cardioDetail: "Distance"
        default: "Workout count"
        }
    }

    private func metricValue(for kind: HealthQueryKind) -> Double {
        switch kind {
        case .sleep: 28_800
        case .condition: 82
        case .latestBody, .bodyTrend: 68.4
        case .personalRecord: 40
        case .cardioDetail: 5_000
        default: 4
        }
    }

    private func metricUnit(for kind: HealthQueryKind) -> HealthQueryUnit {
        switch kind {
        case .sleep: .seconds
        case .condition: .score
        case .latestBody, .bodyTrend, .personalRecord: .kilograms
        case .cardioDetail: .meters
        default: .count
        }
    }
}
#endif
