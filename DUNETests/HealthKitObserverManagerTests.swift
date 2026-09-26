import Foundation
import HealthKit
import Synchronization
import Testing
@testable import DUNE

@Suite("HealthKitObserverManager")
struct HealthKitObserverManagerTests {
    @Test("Launch registration is synchronous, idempotent, and fully stopped before restart")
    @MainActor
    func registrationLifecycle() {
        let store = ObserverStoreSpy()
        let manager = HealthKitObserverManager(store: store, coordinator: ObserverRefreshStub())

        manager.startObserving()
        let initialQueries = store.state.withLock { $0.executed }
        #expect(initialQueries.count == 8)
        manager.startObserving()
        #expect(store.state.withLock { $0.executed.count } == 8)
        #expect(store.state.withLock { $0.frequencies.count } == 8)

        manager.stopObserving()
        #expect(store.state.withLock { $0.stopped.map(ObjectIdentifier.init) } == initialQueries.map(ObjectIdentifier.init))
        manager.stopObserving()
        #expect(store.state.withLock { $0.stopped.count } == 8)

        manager.startObserving()
        #expect(store.state.withLock { $0.executed.count } == 16)
        manager.stopObserving()
        #expect(store.state.withLock { $0.stopped.count } == 16)
    }

    @Test("Body composition requests immediate delivery while steps and workouts remain hourly")
    @MainActor
    func bodyCompositionDeliveryFrequency() {
        let store = ObserverStoreSpy()
        let manager = HealthKitObserverManager(store: store, coordinator: ObserverRefreshStub())
        manager.startObserving()
        let frequencies = store.state.withLock { $0.frequencies }
        for identifier: HKQuantityTypeIdentifier in [.bodyMass, .bodyFatPercentage, .bodyMassIndex] {
            #expect(frequencies[HKQuantityType(identifier).identifier] == .immediate)
        }
        #expect(frequencies[HKQuantityType(.stepCount).identifier] == .hourly)
        #expect(frequencies[HKSampleType.workoutType().identifier] == .hourly)
        manager.stopObserving()
    }

    @Test("Observer completion waits for asynchronous work and fires once", arguments: [false, true])
    func completionWaits(cancel: Bool) async {
        let gate = ObserverWorkGate()
        let completions = Mutex(0)
        let task = HealthKitObserverManager.processUpdate(completion: {
            completions.withLock { $0 += 1 }
        }) {
            await gate.wait()
        }
        await gate.waitUntilStarted()
        #expect(completions.withLock { $0 } == 0)
        if cancel { task.cancel() }
        #expect(completions.withLock { $0 } == 0)
        await gate.release()
        await task.value
        #expect(completions.withLock { $0 } == 1)
    }
}

private final class ObserverStoreSpy: HealthKitObserverStoring {
    struct State {
        var executed: [HKQuery] = []
        var stopped: [HKQuery] = []
        var frequencies: [String: HKUpdateFrequency] = [:]
    }

    let state = Mutex(State())

    func execute(_ query: HKQuery) {
        state.withLock { $0.executed.append(query) }
    }

    func stop(_ query: HKQuery) {
        state.withLock { $0.stopped.append(query) }
    }

    func enableBackgroundDelivery(
        for type: HKObjectType,
        frequency: HKUpdateFrequency,
        withCompletion completion: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        state.withLock { $0.frequencies[type.identifier] = frequency }
        completion(true, nil)
    }
}

private struct ObserverRefreshStub: AppRefreshCoordinating {
    func requestRefresh(source: RefreshSource) async -> Bool { false }
    func forceRefresh() async {}
    func invalidateCacheOnly() async {}
    func makeRefreshStream() async -> AsyncStream<RefreshSource> {
        AsyncStream { $0.finish() }
    }
}

private actor ObserverWorkGate {
    private var work: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            work = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if work != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func release() {
        work?.resume()
        work = nil
    }
}
