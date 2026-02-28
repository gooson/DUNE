import Foundation

actor AppRefreshCoordinatorImpl: AppRefreshCoordinating {
    private let sharedHealthDataService: SharedHealthDataService
    private let throttleInterval: TimeInterval
    private let nowProvider: @Sendable () -> Date

    // Initialized to "now" so the first minute after launch is throttled
    // (app's .task already loads fresh data).
    private var lastRefreshDate: Date

    private let continuation: AsyncStream<RefreshSource>.Continuation
    nonisolated let refreshNeededStream: AsyncStream<RefreshSource>

    init(
        sharedHealthDataService: SharedHealthDataService,
        throttleInterval: TimeInterval = 60,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.throttleInterval = throttleInterval
        self.nowProvider = nowProvider
        self.lastRefreshDate = nowProvider()

        let (stream, continuation) = AsyncStream<RefreshSource>.makeStream()
        self.refreshNeededStream = stream
        self.continuation = continuation
    }

    func requestRefresh(source: RefreshSource) async -> Bool {
        let now = nowProvider()
        let elapsed = now.timeIntervalSince(lastRefreshDate)

        guard elapsed >= throttleInterval else {
            AppLogger.ui.debug("[AppRefreshCoordinator] Throttled \(source.rawValue) — \(String(format: "%.0f", elapsed))s since last refresh")
            return false
        }

        lastRefreshDate = now
        await sharedHealthDataService.invalidateCache()
        continuation.yield(source)

        AppLogger.ui.info("[AppRefreshCoordinator] Refresh triggered by \(source.rawValue)")
        return true
    }

    func forceRefresh() async {
        lastRefreshDate = nowProvider()
        await sharedHealthDataService.invalidateCache()
        continuation.yield(.pullToRefresh)

        AppLogger.ui.info("[AppRefreshCoordinator] Force refresh triggered")
    }

    func invalidateCacheOnly() async {
        await sharedHealthDataService.invalidateCache()
        AppLogger.ui.info("[AppRefreshCoordinator] Cache invalidated (background delivery)")
    }
}
