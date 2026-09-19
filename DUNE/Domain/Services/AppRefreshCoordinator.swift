import Foundation

/// Source that triggered a data refresh.
enum RefreshSource: String, Sendable {
    case foreground
    case healthKitObserver
    case backgroundDelivery
    case pullToRefresh
    case cloudKitRemoteChange
}

/// Coordinates app-wide data refresh with throttling.
///
/// Single entry point for all automatic refresh triggers (foreground resume,
/// HealthKit observer callbacks, background delivery). Pull-to-refresh bypasses
/// this coordinator and calls ViewModel reload directly.
protocol AppRefreshCoordinating: Sendable {
    /// Request a refresh. Returns `true` if refresh was triggered, `false` if throttled.
    func requestRefresh(source: RefreshSource) async -> Bool

    /// Force refresh regardless of throttle (for manual triggers).
    func forceRefresh() async

    /// Invalidate cache without triggering UI reload (background delivery).
    func invalidateCacheOnly() async

    /// Registers an independent subscription to refresh events.
    /// Each consumer must request its own stream; cancellation only ends that subscription.
    func makeRefreshStream() async -> AsyncStream<RefreshSource>
}
