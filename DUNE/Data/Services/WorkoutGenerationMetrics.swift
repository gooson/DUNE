#if os(iOS)
import Foundation
import MetricKit
import OSLog
import StateReporting
import Synchronization

/// Measures one model response attempt. No request or generated content enters telemetry.
final class WorkoutGenerationMetrics: Sendable {
    static let shared = WorkoutGenerationMetrics()
    static let category = "AIWorkoutGeneration"
    static let intervalName: StaticString = "ModelResponse"
    static let stateDomain = "com.raftel.dailve.ai-workout-generation"
    private static let stateReporter = StateReporter<Never, Never>.reporter(for: stateDomain)

    private let log = MetricManager.logHandle(category: category)
    private let activeIntervals = Mutex(0)
    private let reportState: @Sendable (String?) -> Void

    init(reportState: @escaping @Sendable (String?) -> Void = { state in
        WorkoutGenerationMetrics.stateReporter.reportTransition(to: state)
    }) {
        self.reportState = reportState
    }

    func measure<Result>(_ operation: () async throws -> Result) async rethrows -> Result {
        let id = begin()
        do {
            let result = try await operation()
            end(id)
            return result
        } catch {
            end(id)
            throw error
        }
    }

    private func begin() -> OSSignpostID {
        activeIntervals.withLock { count in
            if count == 0 { reportState("generating") }
            count += 1
        }
        let id = OSSignpostID(log: log)
        // Keep MetricKit's default metrics snapshot; never add user metadata.
        mxSignpost(.begin, log: log, name: Self.intervalName, signpostID: id)
        return id
    }

    private func end(_ id: OSSignpostID) {
        mxSignpost(.end, log: log, name: Self.intervalName, signpostID: id)
        activeIntervals.withLock { count in
            count -= 1
            if count == 0 { reportState(nil) }
        }
    }
}

/// Retained by the app from launch; consumes only allowlisted daily aggregates.
final class WorkoutGenerationMetricMonitor {
    private let manager: MetricManager
    private let reportTask: Task<Void, Never>
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "AIWorkoutPerformance")

    init() {
        let manager = MetricManager(enabledStateReportingDomains: [
            StateReportingDomain(rawValue: WorkoutGenerationMetrics.stateDomain)
        ])
        self.manager = manager
        reportTask = Task.detached(priority: .utility) {
            for await report in manager.metricReports {
                guard !Task.isCancelled else { return }
                Self.reportAggregates(report)
            }
        }
    }

    deinit {
        reportTask.cancel()
    }

    private static func reportAggregates(_ report: MetricReport) {
        // Smaller windows and state entries overlap the daily totals; do not sum them.
        for value in report.intervalEntries.fullDayEntry.values {
            guard case let .signpostInterval(metric) = value,
                  metric.signpostCategory == WorkoutGenerationMetrics.category,
                  metric.signpostName == "ModelResponse" else { continue }

            logger.info("ModelResponse daily count=\(metric.totalCount, privacy: .public)")
            for bucket in metric.signpostDuration.buckets {
                let lowerSeconds = bucket.lowerBound.converted(to: .seconds).value
                let upperSeconds = bucket.upperBound.converted(to: .seconds).value
                logger.info("ModelResponse duration lowerSeconds=\(lowerSeconds, privacy: .public) upperSeconds=\(upperSeconds, privacy: .public) count=\(bucket.count, privacy: .public)")
            }
            if let cpu = metric.cpuTime {
                let seconds = cpu.converted(to: .seconds).value
                logger.info("ModelResponse cpuSeconds=\(seconds, privacy: .public)")
            }
            if let memory = metric.averageMemory {
                let bytes = memory.average.converted(to: .bytes).value
                logger.info("ModelResponse averageMemoryBytes=\(bytes, privacy: .public) sampleCount=\(memory.count, privacy: .public)")
            }
        }
    }
}
#endif
