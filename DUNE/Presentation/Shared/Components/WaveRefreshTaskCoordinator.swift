import Foundation

/// Keeps a refresh alive when SwiftUI cancels its refresh action during a render update.
/// The visible screen owns cancellation through `cancel()` instead.
@MainActor
final class WaveRefreshTaskCoordinator {
    private var task: Task<Void, Never>?

    func run(_ operation: @escaping @MainActor @Sendable () async -> Void) async {
        if let task {
            await task.value
            return
        }

        let task = Task { @MainActor in
            await operation()
        }
        self.task = task
        await task.value
        self.task = nil
    }

    func cancel() {
        // Keep the cancelled task tracked until it drains so a second refresh
        // cannot race the old operation's cleanup.
        task?.cancel()
    }
}
