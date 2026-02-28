import Foundation

/// Source that triggered a data refresh.
enum RefreshSource: String, Sendable {
    case foreground
    case healthKitObserver
    case backgroundDelivery
    case pullToRefresh
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

    /// Stream that emits when UI should reload. ContentView listens to this.
    var refreshNeededStream: AsyncStream<RefreshSource> { get }
}
