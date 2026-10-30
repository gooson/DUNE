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
            limitations.append(String(localized: "The result is limited to the most recent 2,000 records in this period.", locale: HealthQueryLocalization.locale))
        }
        // Project all SwiftData values before the first suspension.
        let definitions: [(String, String, HealthQueryUnit, ClosedRange<Double>, BodyCompositionSampleKind?)] = [
            ("weight", String(localized: "Weight", locale: HealthQueryLocalization.locale), .kilograms, 0.001...500, .weight),
            ("bodyFat", String(localized: "Body Fat", locale: HealthQueryLocalization.locale), .percent, 0...100, .bodyFatPercentage),
            ("leanBodyMass", String(localized: "Lean Body Mass", locale: HealthQueryLocalization.locale), .kilograms, 0.001...300, .leanBodyMass),
            ("bmi", String(localized: "BMI", locale: HealthQueryLocalization.locale), .bodyMassIndex, 0.001...100, nil)
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
            limitations.append(String(localized: "Some Health app body measurements could not be read. Available records are shown.", locale: HealthQueryLocalization.locale))
        }
        var metrics: [HealthQueryMetric] = []
        var series: [HealthQuerySeries] = []
        var sources: [HealthQuerySource] = []
        for (index, definition) in definitions.enumerated() {
            let samples = remote[index] ?? []
            if samples.count > Self.maximumRecords {
                limitations.append(String(localized: "Health app results are limited to the most recent 2,000 records in this period.", locale: HealthQueryLocalization.locale))
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
        let summary: String
        if metrics.isEmpty {
            summary = limitations.isEmpty
                ? String(localized: "No body measurements were found in this period.", locale: HealthQueryLocalization.locale)
                : String(localized: "Body measurements could not be read. Try again later.", locale: HealthQueryLocalization.locale)
        } else {
            summary = String(localized: "Your available body measurements are shown with their measurement dates.", locale: HealthQueryLocalization.locale)
        }
        return result(request.kind, status: metrics.isEmpty ? (limitations.isEmpty ? .noData : .unavailable) : (limitations.isEmpty ? .available : .partial),
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
                              summary: String(localized: "No sleep records were found in this period.", locale: HealthQueryLocalization.locale))
            }
            let total = points.reduce(0) { $0 + $1.value }
            let fetchedAt = nowProvider()
            let measurementDate = points.count == 1 ? points.first?.date : nil
            var metrics = [HealthQueryMetric(id: "sleepTotal", title: String(localized: "Total Sleep", locale: HealthQueryLocalization.locale), value: total, unit: .seconds, date: measurementDate),
                           HealthQueryMetric(id: "sleepAverage", title: String(localized: "Average Recorded Sleep", locale: HealthQueryLocalization.locale), value: total / Double(points.count), unit: .seconds, date: measurementDate),
                           HealthQueryMetric(id: "recordedNights", title: String(localized: "Recorded Nights", locale: HealthQueryLocalization.locale), value: Double(points.count), unit: .count)]
            let stages: [(SleepStage.Stage, String)] = [(.deep, String(localized: "Deep Sleep", locale: HealthQueryLocalization.locale)), (.rem, String(localized: "REM Sleep", locale: HealthQueryLocalization.locale)), (.core, String(localized: "Core Sleep", locale: HealthQueryLocalization.locale))]
            for (stage, title) in stages {
                let values = days.filter { $0.date >= interval.start && $0.date < interval.end && Self.valid($0.totalMinutes, in: 0.001...1_440) != nil }
                    .compactMap { Self.valid($0.stageBreakdown[stage], in: 0...1_440) }
                if !values.isEmpty {
                    metrics.append(HealthQueryMetric(id: "sleep-\(String(describing: stage))", title: title, value: values.reduce(0, +) * 60, unit: .seconds, date: measurementDate))
                }
            }
            return result(request.kind, interval: interval,
                          metrics: metrics,
                          series: [HealthQuerySeries(id: "sleep", title: String(localized: "Sleep", locale: HealthQueryLocalization.locale), unit: .seconds, points: points)],
                          sources: points.map { HealthQuerySource(kind: .healthKit, measuredAt: $0.date, fetchedAt: fetchedAt) },
                          summary: String(localized: "From \(dateText(interval.start)) through \(dateText(interval.end)).", locale: HealthQueryLocalization.locale) + " " + String(localized: "Sleep totals include only nights with recorded sleep.", locale: HealthQueryLocalization.locale))
        } catch is CancellationError { throw CancellationError() }
        catch {
            return result(request.kind, status: .unavailable, interval: interval,
                          summary: String(localized: "Sleep records could not be read. Try again later.", locale: HealthQueryLocalization.locale), isComplete: false)
        }
    }

    func conditionResult(_ request: HealthQueryRequest, interval: DateInterval) async throws -> HealthQueryResult {
        guard let sharedHealthDataService else {
            return result(request.kind, status: .unavailable, interval: interval,
                          summary: String(localized: "Condition data is not available yet. Open DUNE and try again.", locale: HealthQueryLocalization.locale), isComplete: false)
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
        let conditionSources: Set<SharedHealthSnapshot.Source> = [.hrvSamples, .todayRHR, .yesterdayRHR, .latestRHR, .rhrCollection]
        if !snapshot.failedSources.isDisjoint(with: conditionSources) {
            limitations.append(String(localized: "Some health sources could not be refreshed. Available condition records are shown.", locale: HealthQueryLocalization.locale))
        }
        let age = nowProvider().timeIntervalSince(snapshot.fetchedAt)
        if !age.isFinite || age < -1 || age > 3_600 {
            limitations.append(String(localized: "Condition data was last refreshed earlier. Check the source dates.", locale: HealthQueryLocalization.locale))
        }
        let latest = points.last
        var metrics = latest.map {
            [HealthQueryMetric(id: "condition", title: String(localized: "Condition Score", locale: HealthQueryLocalization.locale),
                               value: $0.value, unit: .score, date: $0.date)]
        } ?? []
        var sources = points.map { HealthQuerySource(kind: .calculated, measuredAt: $0.date, fetchedAt: snapshot.fetchedAt) }
        let hrv = snapshot.hrvSamples.filter {
            $0.date >= interval.start && $0.date < interval.end && Self.valid($0.value, in: 0.001...500) != nil
        }.max { $0.date < $1.date }
        if let hrv {
            metrics.append(HealthQueryMetric(id: "hrv", title: String(localized: "Heart Rate Variability", locale: HealthQueryLocalization.locale),
                                             value: hrv.value, unit: .milliseconds, date: hrv.date))
            sources.append(HealthQuerySource(kind: .healthKit, measuredAt: hrv.date, fetchedAt: snapshot.fetchedAt))
        }
        // Use dated samples, never assign today's date to an undated scalar.
        let rhrSamples = snapshot.rhrCollection.map { SharedHealthSnapshot.RHRSample(value: $0.average, date: $0.date) }
            + [snapshot.latestRHR].compactMap { $0 }
        let rhr = rhrSamples.filter {
            $0.date >= interval.start && $0.date < interval.end && Self.valid($0.value, in: 20...300) != nil
        }.max { $0.date < $1.date }
        if let rhr {
            metrics.append(HealthQueryMetric(id: "restingHeartRate", title: String(localized: "Resting Heart Rate", locale: HealthQueryLocalization.locale),
                                             value: rhr.value, unit: .bpm, date: rhr.date))
            sources.append(HealthQuerySource(kind: .healthKit, measuredAt: rhr.date, fetchedAt: snapshot.fetchedAt))
        }
        let summary: String
        if metrics.isEmpty {
            summary = limitations.isEmpty
                ? String(localized: "No condition records were found in this period.", locale: HealthQueryLocalization.locale)
                : String(localized: "Condition records could not be read. Try again later.", locale: HealthQueryLocalization.locale)
        } else {
            summary = String(localized: "Condition records describe wellness trends and are not a medical assessment.", locale: HealthQueryLocalization.locale)
        }
        return result(request.kind, status: metrics.isEmpty ? (limitations.isEmpty ? .noData : .unavailable) : (limitations.isEmpty ? .available : .partial),
                      interval: interval, metrics: metrics,
                      series: points.isEmpty ? [] : [HealthQuerySeries(id: "condition", title: String(localized: "Condition Score", locale: HealthQueryLocalization.locale), unit: .score, points: points)],
                      sources: sources, summary: summary,
                      limitations: limitations, isComplete: limitations.isEmpty)
    }
}
