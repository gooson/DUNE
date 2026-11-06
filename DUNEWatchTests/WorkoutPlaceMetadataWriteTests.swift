import Foundation
import Testing
@testable import DUNEWatch

@Suite("Watch workout place metadata write")
@MainActor
struct WorkoutPlaceMetadataWriteTests {
    private enum TestFailure: Error { case write }

    private final class Writer {
        var callback: (@Sendable (Bool, (any Error)?) -> Void)?
        var onStart: (() -> Void)?
        var startCount = 0

        func start(_ callback: @escaping @Sendable (Bool, (any Error)?) -> Void) {
            startCount += 1
            self.callback = callback
            onStart?()
        }
    }

    @Test("Withheld callback times out and late callbacks cannot complete finalization twice")
    func withheldAndLateCallback() async {
        let writer = Writer()
        var completions = 0
        do {
            try await WorkoutPlaceMetadataWrite.perform(timeout: .milliseconds(1), operation: writer.start)
            Issue.record("A withheld callback must time out")
        } catch {
            #expect(error as? WorkoutPlaceMetadataWrite.Failure == .timedOut)
        }
        completions += 1
        #expect(writer.startCount == 1)
        writer.callback?(true, nil)
        writer.callback?(false, TestFailure.write)
        #expect(completions == 1)
    }

    @Test("A delayed successful callback releases the caller before the deadline")
    func delayedSuccess() async throws {
        let writer = Writer()
        var task: Task<Void, any Error>?
        await withCheckedContinuation { started in
            writer.onStart = { started.resume() }
            task = Task { try await WorkoutPlaceMetadataWrite.perform(timeout: .seconds(1), operation: writer.start) }
        }
        writer.callback?(true, nil)
        try await task?.value
        #expect(writer.startCount == 1)
    }

    @Test("Callback failure is returned without waiting for the deadline")
    func failure() async {
        do {
            try await WorkoutPlaceMetadataWrite.perform(timeout: .seconds(1)) { completion in
                completion(false, TestFailure.write)
            }
            Issue.record("Callback failure must throw")
        } catch {
            #expect(error is TestFailure)
        }
    }

    @Test("A false callback without an error still reports failure")
    func missingResult() async {
        do {
            try await WorkoutPlaceMetadataWrite.perform(timeout: .seconds(1)) { $0(false, nil) }
            Issue.record("Missing success must throw")
        } catch {
            #expect(error as? WorkoutPlaceMetadataWrite.Failure == .missingResult)
        }
    }

    @Test("Cancellation releases a withheld callback and ignores subsequent success")
    func cancellationWhileWaiting() async {
        let writer = Writer()
        var task: Task<Void, any Error>?
        await withCheckedContinuation { started in
            writer.onStart = { started.resume() }
            task = Task { try await WorkoutPlaceMetadataWrite.perform(timeout: .seconds(1), operation: writer.start) }
        }
        task?.cancel()
        do {
            try await task?.value
            Issue.record("Cancellation must throw")
        } catch {
            #expect(error is CancellationError)
        }
        writer.callback?(true, nil)
        #expect(writer.startCount == 1)
    }

    @Test("Cancellation before registration never starts metadata writing")
    func cancellationBeforeStart() async {
        let writer = Writer()
        let task = Task { try await WorkoutPlaceMetadataWrite.perform(timeout: .seconds(1), operation: writer.start) }
        task.cancel()
        do {
            try await task.value
            Issue.record("Cancellation must throw")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(writer.startCount == 0)
    }

    @Test("An expired finalization budget never starts metadata writing")
    func expiredBudget() async {
        let writer = Writer()
        do {
            try await WorkoutPlaceMetadataWrite.perform(timeout: .zero, operation: writer.start)
            Issue.record("Expired budget must throw")
        } catch {
            #expect(error as? WorkoutPlaceMetadataWrite.Failure == .timedOut)
        }
        #expect(writer.startCount == 0)
    }

    @Test("Duplicate synchronous callbacks resolve the wait exactly once")
    func duplicateCompletion() async throws {
        try await WorkoutPlaceMetadataWrite.perform(timeout: .seconds(1)) { completion in
            completion(true, nil)
            completion(false, TestFailure.write)
            completion(true, nil)
        }
    }
}
