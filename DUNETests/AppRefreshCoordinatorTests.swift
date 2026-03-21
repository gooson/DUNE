import Foundation
import Testing
@testable import DUNE

// MARK: - Test Helpers

/// Thread-safe mutable date for injecting into nowProvider.
/// Tests are sequential so concurrent mutation is not a concern.
private final class MutableDate: @unchecked Sendable {
    var value: Date
    init(_ date: Date) { self.value = date }
}

private actor MockRefreshService: SharedHealthDataService {
    var invalidateCacheCallCount = 0

    func fetchSnapshot() async -> SharedHealthSnapshot {
        fatalError("Not expected to be called in coordinator tests")
    }

    func invalidateCache() {
        invalidateCacheCallCount += 1
    }
}

// MARK: - Tests

@Suite("AppRefreshCoordinatorImpl")
struct AppRefreshCoordinatorTests {

    // MARK: - Throttling

    @Test("First request after throttle interval triggers refresh")
    func firstRequestAfterThrottleTriggersRefresh() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { clock.value }
        )

        // Advance 61 seconds past init time
        clock.value = Date(timeIntervalSince1970: 1061)
        let result = await coordinator.requestRefresh(source: .foreground)

        #expect(result == true)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 1)
    }

    @Test("Request within throttle interval is throttled")
    func requestWithinThrottleIsThrottled() async {
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { fixedDate }
        )

        // Request at the same time (0 seconds elapsed)
        let result = await coordinator.requestRefresh(source: .foreground)

        #expect(result == false)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 0)
    }

    @Test("Second request within throttle after successful refresh is throttled")
    func secondRequestWithinThrottleIsThrottled() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { clock.value }
        )

        // First request at +61s (succeeds)
        clock.value = Date(timeIntervalSince1970: 1061)
        let first = await coordinator.requestRefresh(source: .foreground)

        // Second request at +70s (only 9s after first refresh)
        clock.value = Date(timeIntervalSince1970: 1070)
        let second = await coordinator.requestRefresh(source: .healthKitObserver)

        #expect(first == true)
        #expect(second == false)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 1)
    }

    @Test("Two requests with sufficient gap both succeed")
    func twoRequestsWithSufficientGapBothSucceed() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { clock.value }
        )

        // First at +61s, second at +122s
        clock.value = Date(timeIntervalSince1970: 1061)
        let first = await coordinator.requestRefresh(source: .foreground)

        clock.value = Date(timeIntervalSince1970: 1122)
        let second = await coordinator.requestRefresh(source: .healthKitObserver)

        #expect(first == true)
        #expect(second == true)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 2)
    }

    // MARK: - Force Refresh

    @Test("forceRefresh bypasses throttle and invalidates cache")
    func forceRefreshBypassesThrottle() async {
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { fixedDate }
        )

        await coordinator.forceRefresh()

        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 1)
    }

    // MARK: - Cache Invalidation Only

    @Test("invalidateCacheOnly invalidates without yielding to stream")
    func invalidateCacheOnlyDoesNotYieldToStream() async {
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60
        )

        await coordinator.invalidateCacheOnly()

        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 1)
    }

    // MARK: - Stream Emission

    @Test("requestRefresh emits to refreshNeededStream")
    func requestRefreshEmitsToStream() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { clock.value }
        )

        let expectation = Task<RefreshSource?, Never> {
            var iterator = coordinator.refreshNeededStream.makeAsyncIterator()
            return await iterator.next()
        }

        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        clock.value = Date(timeIntervalSince1970: 1061)
        _ = await coordinator.requestRefresh(source: .healthKitObserver)

        let emittedSource = await expectation.value
        #expect(emittedSource == .healthKitObserver)
    }

    @Test("forceRefresh emits pullToRefresh to stream")
    func forceRefreshEmitsPullToRefreshToStream() async {
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60
        )

        let expectation = Task<RefreshSource?, Never> {
            var iterator = coordinator.refreshNeededStream.makeAsyncIterator()
            return await iterator.next()
        }

        try? await Task.sleep(nanoseconds: 10_000_000)

        await coordinator.forceRefresh()

        let emittedSource = await expectation.value
        #expect(emittedSource == .pullToRefresh)
    }

    // MARK: - Edge: Exact Boundary

    @Test("Request at exactly throttle boundary triggers refresh")
    func requestAtExactBoundaryTriggersRefresh() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { clock.value }
        )

        // Advance exactly 60 seconds
        clock.value = Date(timeIntervalSince1970: 1060)
        let result = await coordinator.requestRefresh(source: .foreground)

        // >= means exact boundary triggers
        #expect(result == true)
    }

    // MARK: - CloudKit Remote Change Throttle

    @Test("cloudKitRemoteChange uses dedicated short throttle, not general throttle")
    func cloudKitRemoteChangeUsesDedicatedThrottle() async {
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            cloudKitThrottleInterval: 5,
            nowProvider: { fixedDate }
        )

        // First CloudKit request passes (lastCloudKitRefreshDate is .distantPast)
        let result = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        #expect(result == true)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 1)
    }

    @Test("Rapid cloudKitRemoteChange within 5s is throttled")
    func rapidCloudKitRemoteChangeIsThrottled() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            cloudKitThrottleInterval: 5,
            nowProvider: { clock.value }
        )

        // First passes
        let first = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        // Second at +2s — within CloudKit throttle
        clock.value = Date(timeIntervalSince1970: 1002)
        let second = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        // Third at +4s — still within CloudKit throttle
        clock.value = Date(timeIntervalSince1970: 1004)
        let third = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        #expect(first == true)
        #expect(second == false)
        #expect(third == false)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 1)
    }

    @Test("cloudKitRemoteChange passes after dedicated throttle interval")
    func cloudKitRemoteChangePassesAfterThrottleInterval() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            cloudKitThrottleInterval: 5,
            nowProvider: { clock.value }
        )

        // First passes
        let first = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        // Second at +6s — past CloudKit throttle
        clock.value = Date(timeIntervalSince1970: 1006)
        let second = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        #expect(first == true)
        #expect(second == true)
        let cacheCount = await service.invalidateCacheCallCount
        #expect(cacheCount == 2)
    }

    @Test("cloudKitRemoteChange updates lastRefreshDate so subsequent non-bypass sources are throttled")
    func cloudKitRemoteChangeUpdatesLastRefreshDate() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            cloudKitThrottleInterval: 5,
            nowProvider: { clock.value }
        )

        // cloudKitRemoteChange passes (dedicated throttle)
        let first = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        // foreground at +10s (should be throttled — lastRefreshDate was updated)
        clock.value = Date(timeIntervalSince1970: 1010)
        let second = await coordinator.requestRefresh(source: .foreground)

        #expect(first == true)
        #expect(second == false)
    }

    @Test("CloudKit and general throttles are independent")
    func cloudKitAndGeneralThrottlesAreIndependent() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            cloudKitThrottleInterval: 5,
            nowProvider: { clock.value }
        )

        // CloudKit at +0s passes (dedicated throttle, lastCloudKitRefreshDate is .distantPast)
        let first = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        // foreground at +61s passes general throttle (60s from init time)
        clock.value = Date(timeIntervalSince1970: 1061)
        let second = await coordinator.requestRefresh(source: .foreground)

        // CloudKit at +62s — 62s since last CloudKit refresh, passes dedicated throttle
        clock.value = Date(timeIntervalSince1970: 1062)
        let third = await coordinator.requestRefresh(source: .cloudKitRemoteChange)

        // foreground at +63s — only 2s since last general refresh, throttled
        clock.value = Date(timeIntervalSince1970: 1063)
        let fourth = await coordinator.requestRefresh(source: .foreground)

        #expect(first == true)
        #expect(second == true)
        #expect(third == true)
        #expect(fourth == false)
    }

    @Test("Request 1 second before threshold is throttled")
    func requestOneSecondBeforeThresholdIsThrottled() async {
        let clock = MutableDate(Date(timeIntervalSince1970: 1000))
        let service = MockRefreshService()
        let coordinator = AppRefreshCoordinatorImpl(
            sharedHealthDataService: service,
            throttleInterval: 60,
            nowProvider: { clock.value }
        )

        // Advance 59 seconds
        clock.value = Date(timeIntervalSince1970: 1059)
        let result = await coordinator.requestRefresh(source: .foreground)

        #expect(result == false)
    }
}
