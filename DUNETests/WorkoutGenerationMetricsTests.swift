import Synchronization
import Testing
@testable import DUNE

@Suite("WorkoutGenerationMetrics")
struct WorkoutGenerationMetricsTests {
    private final class States: Sendable {
        let values = Mutex<[String?]>([])

        func append(_ value: String?) {
            values.withLock { $0.append(value) }
        }

        var snapshot: [String?] { values.withLock { $0 } }
    }

    private enum Failure: Error { case inference }

    @Test("Successful response preserves result and closes generation state")
    func success() async {
        let states = States()
        let metrics = WorkoutGenerationMetrics(reportState: { states.append($0) })

        let result = await metrics.measure { 42 }

        #expect(result == 42)
        #expect(states.snapshot == ["generating", nil])
    }

    @Test("Throwing response preserves error and closes generation state")
    func failure() async {
        let states = States()
        let metrics = WorkoutGenerationMetrics(reportState: { states.append($0) })

        await #expect(throws: Failure.inference) {
            try await metrics.measure { throw Failure.inference }
        }

        #expect(states.snapshot == ["generating", nil])
    }

    @Test("Cancelled response closes state and propagates cancellation")
    func cancellation() async {
        let states = States()
        let metrics = WorkoutGenerationMetrics(reportState: { states.append($0) })
        let task = Task {
            try await metrics.measure {
                withUnsafeCurrentTask { $0?.cancel() }
                try Task.checkCancellation()
            }
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(states.snapshot == ["generating", nil])
    }

    @Test("Overlapping intervals remain generating until the final response ends")
    func overlap() async {
        let states = States()
        let metrics = WorkoutGenerationMetrics(reportState: { states.append($0) })

        await metrics.measure {
            await metrics.measure { }
            #expect(states.snapshot == ["generating"])
        }

        #expect(states.snapshot == ["generating", nil])
    }

    @Test("A failed attempt ends before a retry starts")
    func retry() async {
        let states = States()
        let metrics = WorkoutGenerationMetrics(reportState: { states.append($0) })

        await #expect(throws: Failure.inference) {
            try await metrics.measure { throw Failure.inference }
        }
        #expect(states.snapshot == ["generating", nil])
        await metrics.measure { }

        #expect(states.snapshot == ["generating", nil, "generating", nil])
    }
}
