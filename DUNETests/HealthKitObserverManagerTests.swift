import Foundation
import Synchronization
import Testing
@testable import DUNE

@Suite("HealthKitObserverManager")
struct HealthKitObserverManagerTests {
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
