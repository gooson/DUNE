import Foundation

/// Optional place enrichment must release workout finalization even if HealthKit never calls back.
@MainActor
enum WorkoutPlaceMetadataWrite {
    enum Failure: Error, Equatable { case timedOut, missingResult }

    static func perform(
        timeout: Duration,
        operation: (@escaping @Sendable (Bool, (any Error)?) -> Void) -> Void
    ) async throws {
        try Task.checkCancellation()
        guard timeout > .zero else { throw Failure.timedOut }
        let gate = WorkoutRouteCallbackGate()
        // Cap this optional operation independently of the caller's finalization budget.
        let timeoutTask = Task { @MainActor in
            do { try await Task.sleep(for: min(timeout, .seconds(1))) } catch { return }
            gate.resolve(.failure(Failure.timedOut))
        }
        defer { timeoutTask.cancel() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard gate.register(continuation) else { return }
                guard !Task.isCancelled else { gate.cancel(); return }
                // The retained HK callback owns only the gate, not the builder or finalization task.
                operation { success, error in
                    if let error { gate.resolve(.failure(error)) }
                    else if success { gate.resolve(.success(())) }
                    else { gate.resolve(.failure(Failure.missingResult)) }
                }
            }
        } onCancel: {
            gate.cancel()
        }
    }
}
