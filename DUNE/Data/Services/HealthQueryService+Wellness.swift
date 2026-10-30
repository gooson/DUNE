import Foundation
import SwiftData

extension HealthQueryService {
    struct BodyQueryValue {
        let value: Double
        let date: Date
        let source: HealthQuerySource
        let syncIdentifier: String?
    }

    /// Deduplicate only the metric actually represented locally; another metric on the
    /// same local record must not hide a HealthKit-only measurement.
    static func mergedBodyValues(local: [BodyQueryValue], remote: [BodyQueryValue]) -> [BodyQueryValue] {
        let represented = Set(local.compactMap(\.syncIdentifier))
        return (local + remote.filter { sample in
            sample.syncIdentifier.map { !represented.contains($0) } ?? true
        }).sorted { $0.date < $1.date }
    }

    func bodyResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        guard let container else { throw HealthQueryServiceError.notConfigured }
        let context = ModelContext(container)
        let start = interval.start
        let end = interval.end
        var descriptor = FetchDescriptor<BodyCompositionRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\BodyCompositionRecord.date, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maximumRecords + 1
        let records = try context.fetch(descriptor)
        let fetchedAt = nowProvider()
        var limitations: [String] = []
        if records.count > Self.maximumRecords {
            limitations.append(String(localized: "The result is limited to the most recent 2,000 records in this period."))
        }
        // Project all SwiftData values before the first suspension.
        let definitions: [(String, String, HealthQueryUnit, ClosedRange<Double>, BodyCompositionSampleKind?)] = [
            ("weight", String(localized: "Weight"), .kilograms, 0.001...500, .weight),
            ("bodyFat", String(localized: "Body Fat"), .percent, 0...100, .bodyFatPercentage),
            ("leanBodyMass", String(localized: "Lean Body Mass"), .kilograms, 0.001...300, .leanBodyMass),
            ("bmi", String(localized: "BMI"), .bodyMassIndex, 0.001...100, nil)
        ]
        let localValues: [[BodyQueryValue]] = definitions.map { definition in
            records.prefix(Self.maximumRecords).compactMap { record in
                let raw: Double?
                switch definition.0 {
                case "weight": raw = record.weight
                case "bodyFat": raw = record.bodyFatPercentage
                case "leanBodyMass": raw = record.muscleMass
                default: raw = nil
                }
                guard let value = Self.valid(raw, in: definition.3) else { return nil }
                return BodyQueryValue(value: value, date: record.date,
                                      source: HealthQuerySource(kind: .app, recordID: record.id.uuidString,
                                                                measuredAt: record.date, fetchedAt: fetchedAt),
                                      syncIdentifier: definition.4.map {
                                          BodyCompositionWriteInput.syncIdentifier(recordID: record.id, kind: $0)
                                      })
            }
        }
        let service = bodyService
        let remote = try await withThrowingTaskGroup(of: (Int, [BodyCompositionSample]?).self) { group in
            for index in definitions.indices {
                group.addTask {
                    do {
                        let samples: [BodyCompositionSample]
                        switch index {
                        case 0: samples = try await service.fetchWeight(start: start, end: end)
                        case 1: samples = try await service.fetchBodyFat(start: start, end: end)
                        case 2: samples = try await service.fetchLeanBodyMass(start: start, end: end)
                        default: samples = try await service.fetchBMI(start: start, end: end)
                        }
                        return (index, samples)
                    } catch is CancellationError { throw CancellationError() }
                    catch { return (index, nil) }
                }
            }
            var results: [Int: [BodyCompositionSample]] = [:]
            for try await (index, samples) in group { if let samples { results[index] = samples } }
            return results
        }
        if remote.count != definitions.count {
            limitations.append(String(localized: "Some Health app body measurements could not be read. Available records are shown."))
        }
        var metrics: [HealthQueryMetric] = []
        var series: [HealthQuerySeries] = []
        var sources: [HealthQuerySource] = []
        for (index, definition) in definitions.enumerated() {
            let samples = remote[index] ?? []
            if samples.count > Self.maximumRecords {
                limitations.append(String(localized: "Health app results are limited to the most recent 2,000 records in this period."))
            }
            let healthValues = samples.filter { $0.date >= start && $0.date < end }
                .sorted { $0.date > $1.date }.prefix(Self.maximumRecords).compactMap { sample -> BodyQueryValue? in
                    guard let value = Self.valid(sample.value, in: definition.3) else { return nil }
                    return BodyQueryValue(value: value, date: sample.date,
                                          source: HealthQuerySource(kind: .healthKit, measuredAt: sample.date,
                                                                    fetchedAt: nowProvider()), syncIdentifier: sample.syncIdentifier)
                }
            let values = Self.mergedBodyValues(local: localValues[index], remote: healthValues)
            guard let latest = values.last else { continue }
            let baseline = request.kind == .bodyTrend && values.count > 1 ? values.first : nil
            metrics.append(HealthQueryMetric(id: definition.0, title: definition.1, value: latest.value,
                                             unit: definition.2, date: latest.date,
                                             comparisonValue: baseline?.value, comparisonDate: baseline?.date))
            if request.kind == .bodyTrend {
                series.append(HealthQuerySeries(id: definition.0, title: definition.1, unit: definition.2,
                                                points: values.map { HealthQueryPoint(date: $0.date, value: $0.value) }))
                sources.append(contentsOf: values.map(\.source))
            } else { sources.append(latest.source) }
        }
        let summary = metrics.isEmpty ? String(localized: "No body measurements were found in this period.")
            : String(localized: "Your available body measurements are shown with their measurement dates.")
        return result(request.kind, status: limitations.isEmpty ? (metrics.isEmpty ? .noData : .available) : .partial,
                      interval: interval, metrics: metrics, series: series, sources: sources, summary: summary,
                      limitations: Array(Set(limitations)).sorted(), isComplete: limitations.isEmpty)
    }

    func sleepResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        do {
            // This API uses the app's sleep-day attribution and excludes awake stages.
            // Do not substitute the latest available night outside the requested period.
            let days = try await sleepService.fetchDailySleepDurations(start: interval.start, end: interval.end)
            try Task.checkCancellation()
            let points = days.compactMap { day -> HealthQueryPoint? in
                guard day.date >= interval.start, day.date < interval.end,
                      let minutes = Self.valid(day.totalMinutes, in: 0.001...1_440) else { return nil }
                return HealthQueryPoint(date: day.date, value: minutes * 60)
            }.sorted { $0.date < $1.date }
            guard !points.isEmpty else {
                return result(request.kind, status: .noData, interval: interval,
                              summary: String(localized: "No sleep records were found in this period."))
            }
            let total = points.reduce(0) { $0 + $1.value }
            let fetchedAt = nowProvider()
            return result(request.kind, interval: interval,
                          metrics: [HealthQueryMetric(id: "sleepTotal", title: String(localized: "Total Sleep"), value: total, unit: .seconds),
                                    HealthQueryMetric(id: "sleepAverage", title: String(localized: "Average Recorded Sleep"),
                                                      value: total / Double(points.count), unit: .seconds)],
                          series: [HealthQuerySeries(id: "sleep", title: String(localized: "Sleep"), unit: .seconds, points: points)],
                          sources: points.map { HealthQuerySource(kind: .healthKit, measuredAt: $0.date, fetchedAt: fetchedAt) },
                          summary: String(localized: "Sleep totals include only nights with recorded sleep."))
        } catch is CancellationError { throw CancellationError() }
        catch {
            return result(request.kind, status: .unavailable, interval: interval,
                          summary: String(localized: "Sleep records could not be read. Try again later."), isComplete: false)
        }
    }

    func conditionResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        guard let sharedHealthDataService else {
            return result(request.kind, status: .unavailable, interval: interval,
                          summary: String(localized: "Condition data is not available yet. Open DUNE and try again."), isComplete: false)
        }
        let snapshot = await sharedHealthDataService.fetchSnapshot()
        try Task.checkCancellation()
        let candidates = snapshot.recentConditionScores + [snapshot.conditionScore].compactMap { $0 }
        let scores = candidates.filter {
            $0.date >= interval.start && $0.date < interval.end && (0...100).contains($0.score)
        }.sorted { $0.date < $1.date }
        var byDate: [Date: ConditionScore] = [:]
        for score in scores { byDate[score.date] = score }
        let points = byDate.values.sorted { $0.date < $1.date }.map { HealthQueryPoint(date: $0.date, value: Double($0.score)) }
        var limitations: [String] = []
        if !snapshot.failedSources.isEmpty {
            limitations.append(String(localized: "Some health sources could not be refreshed. Available condition scores are shown."))
        }
        let age = nowProvider().timeIntervalSince(snapshot.fetchedAt)
        if !age.isFinite || age < -1 || age > 3_600 {
            limitations.append(String(localized: "Condition data was last refreshed earlier. Check the source dates."))
        }
        let latest = points.last
        return result(request.kind, status: limitations.isEmpty ? (latest == nil ? .noData : .available) : .partial,
                      interval: interval,
                      metrics: latest.map { [HealthQueryMetric(id: "condition", title: String(localized: "Condition Score"),
                                                               value: $0.value, unit: .score, date: $0.date)] } ?? [],
                      series: points.isEmpty ? [] : [HealthQuerySeries(id: "condition", title: String(localized: "Condition Score"), unit: .score, points: points)],
                      sources: points.map { HealthQuerySource(kind: .calculated, measuredAt: $0.date, fetchedAt: snapshot.fetchedAt) },
                      summary: latest == nil ? String(localized: "No condition scores were found in this period.")
                        : String(localized: "Condition scores describe recorded wellness trends and are not a medical assessment."),
                      limitations: limitations, isComplete: limitations.isEmpty)
    }
}
