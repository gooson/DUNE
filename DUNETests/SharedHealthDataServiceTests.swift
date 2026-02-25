import Foundation
import Testing
@testable import DUNE

private enum MockServiceError: Error {
    case forcedFailure
}

private actor MockHRVService: HRVQuerying {
    var hrvSamplesCallCount = 0
    var shouldFailSamples = false
    var delayNanoseconds: UInt64 = 0

    private let samples: [HRVSample]
    private let todayRHR: Double?
    private let yesterdayRHR: Double?
    private let latestRHR: (value: Double, date: Date)?
    private let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)]

    init(
        samples: [HRVSample],
        todayRHR: Double?,
        yesterdayRHR: Double?,
        latestRHR: (value: Double, date: Date)?,
        rhrCollection: [(date: Date, min: Double, max: Double, average: Double)]
    ) {
        self.samples = samples
        self.todayRHR = todayRHR
        self.yesterdayRHR = yesterdayRHR
        self.latestRHR = latestRHR
        self.rhrCollection = rhrCollection
    }

    func setDelayNanoseconds(_ nanoseconds: UInt64) {
        delayNanoseconds = nanoseconds
    }

    func setShouldFailSamples(_ shouldFail: Bool) {
        shouldFailSamples = shouldFail
    }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] {
        hrvSamplesCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if shouldFailSamples { throw MockServiceError.forcedFailure }
        return samples
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        if Calendar.current.isDateInYesterday(date) {
            return yesterdayRHR
        }
        return todayRHR
    }

    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        latestRHR
    }

    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] {
        []
    }

    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] {
        rhrCollection
    }
}

private actor MockSleepService: SleepQuerying {
    var sleepStagesCallCount = 0

    private let todayStages: [SleepStage]
    private let yesterdayStages: [SleepStage]
    private let latestStages: (stages: [SleepStage], date: Date)?
    private let sleepDailyDurations: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])]

    init(
        todayStages: [SleepStage],
        yesterdayStages: [SleepStage],
        latestStages: (stages: [SleepStage], date: Date)?,
        sleepDailyDurations: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])]
    ) {
        self.todayStages = todayStages
        self.yesterdayStages = yesterdayStages
        self.latestStages = latestStages
        self.sleepDailyDurations = sleepDailyDurations
    }

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] {
        sleepStagesCallCount += 1
        if Calendar.current.isDateInYesterday(date) {
            return yesterdayStages
        }
        return todayStages
    }

    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? {
        latestStages
    }

    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] {
        sleepDailyDurations
    }

    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? {
        nil
    }
}

@Suite("SharedHealthDataService")
struct SharedHealthDataServiceTests {

    @Test("returns cached snapshot within TTL")
    func cacheHitWithinTTL() async {
        let now = Date()
        let hrvService = MockHRVService(
            samples: [HRVSample(value: 50, date: now)],
            todayRHR: 58,
            yesterdayRHR: 60,
            latestRHR: (value: 58, date: now),
            rhrCollection: [(date: now, min: 55, max: 61, average: 58)]
        )
        let sleepService = MockSleepService(
            todayStages: [SleepStage(stage: .core, duration: 6 * 60 * 60, startDate: now, endDate: now)],
            yesterdayStages: [],
            latestStages: nil,
            sleepDailyDurations: []
        )

        let service = SharedHealthDataServiceImpl(
            hrvService: hrvService,
            sleepService: sleepService,
            cacheTTL: 300
        )

        _ = await service.fetchSnapshot()
        _ = await service.fetchSnapshot()

        let callCount = await hrvService.hrvSamplesCallCount
        #expect(callCount == 1)
    }

    @Test("invalidateCache forces refetch")
    func invalidateCacheRefetches() async {
        let now = Date()
        let hrvService = MockHRVService(
            samples: [HRVSample(value: 50, date: now)],
            todayRHR: 58,
            yesterdayRHR: 60,
            latestRHR: (value: 58, date: now),
            rhrCollection: []
        )
        let sleepService = MockSleepService(
            todayStages: [],
            yesterdayStages: [],
            latestStages: nil,
            sleepDailyDurations: []
        )

        let service = SharedHealthDataServiceImpl(
            hrvService: hrvService,
            sleepService: sleepService,
            cacheTTL: 300
        )

        _ = await service.fetchSnapshot()
        await service.invalidateCache()
        _ = await service.fetchSnapshot()

        let callCount = await hrvService.hrvSamplesCallCount
        #expect(callCount == 2)
    }

    @Test("deduplicates concurrent snapshot requests")
    func concurrentRequestsShareSingleFetch() async {
        let now = Date()
        let hrvService = MockHRVService(
            samples: [HRVSample(value: 50, date: now)],
            todayRHR: 58,
            yesterdayRHR: 60,
            latestRHR: (value: 58, date: now),
            rhrCollection: []
        )
        await hrvService.setDelayNanoseconds(100_000_000)

        let sleepService = MockSleepService(
            todayStages: [],
            yesterdayStages: [],
            latestStages: nil,
            sleepDailyDurations: []
        )

        let service = SharedHealthDataServiceImpl(
            hrvService: hrvService,
            sleepService: sleepService,
            cacheTTL: 300
        )

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = await service.fetchSnapshot()
                }
            }
        }

        let callCount = await hrvService.hrvSamplesCallCount
        #expect(callCount == 1)
    }

    @Test("records failed sources and still returns snapshot")
    func partialFailureIncludesFailedSource() async {
        let now = Date()
        let hrvService = MockHRVService(
            samples: [HRVSample(value: 50, date: now)],
            todayRHR: 58,
            yesterdayRHR: 60,
            latestRHR: nil,
            rhrCollection: []
        )
        await hrvService.setShouldFailSamples(true)

        let sleepService = MockSleepService(
            todayStages: [],
            yesterdayStages: [],
            latestStages: nil,
            sleepDailyDurations: []
        )

        let service = SharedHealthDataServiceImpl(
            hrvService: hrvService,
            sleepService: sleepService,
            cacheTTL: 300
        )

        let snapshot = await service.fetchSnapshot()

        #expect(snapshot.failedSources.contains(.hrvSamples))
        #expect(snapshot.hrvSamples.isEmpty)
    }
}
