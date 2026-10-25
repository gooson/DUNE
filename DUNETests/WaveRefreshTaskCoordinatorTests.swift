import Foundation
import Testing
@testable import DUNE

@MainActor
private final class RefreshTestLatch {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class RefreshOperationProbe {
    var invocationCount = 0
    var wasCancelled = false
}

@Suite("WaveRefreshTaskCoordinator")
@MainActor
struct WaveRefreshTaskCoordinatorTests {
    @Test("Cancelling the caller does not cancel refresh work")
    func callerCancellationDoesNotCancelOperation() async {
        let coordinator = WaveRefreshTaskCoordinator()
        let started = RefreshTestLatch()
        let release = RefreshTestLatch()
        let finished = RefreshTestLatch()
        let probe = RefreshOperationProbe()

        let caller = Task {
            await coordinator.run {
                started.open()
                await release.wait()
                probe.wasCancelled = Task.isCancelled
                finished.open()
            }
        }
        await started.wait()

        caller.cancel()
        release.open()
        await finished.wait()
        await caller.value

        #expect(!probe.wasCancelled)
    }

    @Test("Explicit cancellation cancels the owned refresh task")
    func explicitCancellationCancelsOperation() async {
        let coordinator = WaveRefreshTaskCoordinator()
        let started = RefreshTestLatch()
        let finished = RefreshTestLatch()
        let probe = RefreshOperationProbe()

        let caller = Task {
            await coordinator.run {
                started.open()
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch is CancellationError {
                    probe.wasCancelled = Task.isCancelled
                } catch {
                    Issue.record("Unexpected refresh sleep error: \(error)")
                }
                finished.open()
            }
        }
        await started.wait()

        coordinator.cancel()
        await finished.wait()
        await caller.value

        #expect(probe.wasCancelled)
    }

    @Test("Overlapping calls share one task, and a later call starts fresh work")
    func overlappingCallsCoalesceAndCompletedTaskCanRestart() async {
        let coordinator = WaveRefreshTaskCoordinator()
        let started = RefreshTestLatch()
        let release = RefreshTestLatch()
        let secondEntered = RefreshTestLatch()
        let probe = RefreshOperationProbe()

        let first = Task {
            await coordinator.run {
                probe.invocationCount += 1
                started.open()
                await release.wait()
            }
        }
        await started.wait()

        let second = Task {
            secondEntered.open()
            await coordinator.run { probe.invocationCount += 1 }
        }
        await secondEntered.wait()
        #expect(probe.invocationCount == 1)

        release.open()
        await first.value
        await second.value
        #expect(probe.invocationCount == 1)

        await coordinator.run { probe.invocationCount += 1 }
        #expect(probe.invocationCount == 2)
    }

    @Test("Cancellation keeps the owned task tracked until it finishes")
    func cancelledTaskStillCoalescesUntilCompletion() async {
        let coordinator = WaveRefreshTaskCoordinator()
        let started = RefreshTestLatch()
        let release = RefreshTestLatch()
        let secondEntered = RefreshTestLatch()
        let probe = RefreshOperationProbe()

        let first = Task {
            await coordinator.run {
                probe.invocationCount += 1
                started.open()
                await release.wait()
            }
        }
        await started.wait()
        coordinator.cancel()

        let second = Task {
            secondEntered.open()
            await coordinator.run { probe.invocationCount += 1 }
        }
        await secondEntered.wait()
        #expect(probe.invocationCount == 1)

        release.open()
        await first.value
        await second.value
        #expect(probe.invocationCount == 1)
    }
}
