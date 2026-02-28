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
