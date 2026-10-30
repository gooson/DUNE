import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("Health query wellness")
@MainActor
struct HealthQueryWellnessTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("A mirror is removed only when that metric exists locally")
    func metricSpecificMirrorDedup() {
        let source = HealthQuerySource(kind: .app, fetchedAt: now)
        let local = HealthQueryService.BodyQueryValue(value: 70, date: now, source: source, syncIdentifier: "weight-id")
        let mirror = HealthQueryService.BodyQueryValue(value: 70, date: now, source: source, syncIdentifier: "weight-id")
        let remoteOnly = HealthQueryService.BodyQueryValue(value: 55, date: now, source: source, syncIdentifier: "lean-id")
        let values = HealthQueryService.mergedBodyValues(local: [local], remote: [mirror, remoteOnly])
        #expect(values.count == 2)
        #expect(values.contains { $0.value == 55 })
    }

    @Test("Latest body measurements include today's local record and retain missing values")
    func latestLocalBody() async throws {
        let container = try ModelContainer(for: BodyCompositionRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.insert(BodyCompositionRecord(date: now.addingTimeInterval(-60), weight: 72, bodyFatPercentage: .nan, muscleMass: nil))
        try context.save()
        let clock = now
        let service = HealthQueryService(container: container, bodyService: WellnessBodyStub(), nowProvider: { clock })
        let response = try await service.bodyResult(HealthQueryRequest(kind: .latestBody),
                                                    interval: DateInterval(start: now.addingTimeInterval(-3_600), end: now))
        #expect(response.status == .available)
        #expect(response.metrics.count == 1)
        #expect(response.metrics.first?.value == 72)
        #expect(response.metrics.first?.date == now.addingTimeInterval(-60))
        #expect(response.spokenSummary.contains("72"))
    }

    @Test("HealthKit failure retains local measurements and reports incomplete coverage")
    func bodyPartialFailure() async throws {
        let container = try ModelContainer(for: BodyCompositionRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.insert(BodyCompositionRecord(date: now.addingTimeInterval(-60), weight: 72))
        try context.save()
        let clock = now
        let service = HealthQueryService(container: container, bodyService: WellnessBodyStub(fails: true), nowProvider: { clock })
        let response = try await service.bodyResult(HealthQueryRequest(kind: .latestBody),
                                                    interval: DateInterval(start: now.addingTimeInterval(-3_600), end: now))
        #expect(response.status == .partial)
        #expect(!response.isComplete)
        #expect(response.metrics.first?.value == 72)
    }

    @Test("All failed body reads without local measurements are unavailable")
    func bodyReadFailureWithoutRecords() async throws {
        let container = try ModelContainer(for: BodyCompositionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let clock = now
        let service = HealthQueryService(container: container, bodyService: WellnessBodyStub(fails: true), nowProvider: { clock })
        let response = try await service.bodyResult(HealthQueryRequest(kind: .latestBody),
            interval: DateInterval(start: now.addingTimeInterval(-3_600), end: now))
        #expect(response.status == .unavailable)
        #expect(!response.isComplete)
        #expect(response.metrics.isEmpty)
    }

    @Test("Condition includes dated HRV and RHR in the selected period without inventing freshness")
    func datedConditionMetrics() async throws {
        let clock = now
        let measuredAt = now.addingTimeInterval(-600)
        let fetchedAt = now.addingTimeInterval(-120)
        let snapshot = SharedHealthSnapshot(
            hrvSamples: [HRVSample(value: 45, date: measuredAt), HRVSample(value: .nan, date: now.addingTimeInterval(-1)),
                         HRVSample(value: 90, date: now.addingTimeInterval(-7_200))],
            todayRHR: 100, yesterdayRHR: nil, latestRHR: .init(value: 55, date: measuredAt), rhrCollection: [],
            todaySleepStages: [], yesterdaySleepStages: [], latestSleepStages: nil, sleepDailyDurations: [],
            conditionScore: nil, baselineStatus: nil, recentConditionScores: [], failedSources: [], fetchedAt: fetchedAt)
        let service = HealthQueryService(sharedHealthDataService: WellnessSnapshotStub(snapshot: snapshot), nowProvider: { clock })
        let response = try await service.conditionResult(HealthQueryRequest(kind: .condition),
            interval: DateInterval(start: now.addingTimeInterval(-3_600), end: now))
        #expect(response.status == .available)
        #expect(response.metrics.map(\.value) == [45, 55])
        #expect(response.metrics.allSatisfy { $0.date == measuredAt })
        #expect(response.sources.allSatisfy { $0.kind == .healthKit && $0.fetchedAt == fetchedAt && $0.measuredAt == measuredAt })
        let empty = try await service.conditionResult(HealthQueryRequest(kind: .condition),
            interval: DateInterval(start: now.addingTimeInterval(-300), end: now))
        #expect(empty.status == .noData)
        #expect(empty.metrics.isEmpty)
    }

    @Test("Sleep excludes out-of-period, nonfinite and absent nights")
    func selectedSleepPeriod() async throws {
        let clock = now
        let start = now.addingTimeInterval(-86_400)
        let service = HealthQueryService(sleepService: WellnessSleepStub(start: start), nowProvider: { clock })
        let response = try await service.sleepResult(HealthQueryRequest(kind: .sleep), interval: DateInterval(start: start, end: now))
        #expect(response.series.first?.points.count == 1)
        let average = try #require(response.metrics.first { $0.id == "sleepAverage" }?.value)
        #expect(average == 25_200.0)
        #expect(response.sources.first?.measuredAt == start)
    }
}

private struct WellnessBodyStub: BodyCompositionQuerying {
    var fails = false
    private func samples() throws -> [BodyCompositionSample] {
        if fails { throw CocoaError(.fileReadUnknown) }
        return []
    }
    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { try samples() }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { try samples() }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { try samples() }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] { try samples() }
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] { try samples() }
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] { try samples() }
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] { try samples() }
    func fetchBMI(for date: Date) async throws -> Double? { nil }
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

private struct WellnessSleepStub: SleepQuerying {
    let start: Date
    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] {
        [(self.start.addingTimeInterval(-86_400), 500, [:]), (self.start, 420, [:]),
         (self.start.addingTimeInterval(1), .nan, [:])]
    }
}

private struct WellnessSnapshotStub: SharedHealthDataService {
    let snapshot: SharedHealthSnapshot
    func fetchSnapshot() async -> SharedHealthSnapshot { snapshot }
    func invalidateCache() async {}
}
