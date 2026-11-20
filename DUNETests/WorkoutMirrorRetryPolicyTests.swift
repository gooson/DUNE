import Testing
@testable import DUNE

@Suite("WorkoutMirrorRetryPolicy")
struct WorkoutMirrorRetryPolicyTests {
    @Test("Background outages keep retrying with a bounded delay without a reachability event")
    func repeatedFailures() {
        var policy = WorkoutMirrorRetryPolicy()
        for expected in [5, 10, 20, 40, 80, 120, 120] {
            let delay = policy.scheduleRetry()
            #expect(delay == expected)
            let duplicate = policy.scheduleRetry()
            #expect(duplicate == nil)
            let began = policy.beginRetry()
            #expect(began)
        }
    }

    @Test("Reachability and the timer can only start a pending retry once")
    func reconnectDuringBackoff() {
        var policy = WorkoutMirrorRetryPolicy()
        let idle = policy.beginRetry()
        #expect(!idle)
        _ = policy.scheduleRetry()
        let reconnect = policy.beginRetry()
        #expect(reconnect)
        let timer = policy.beginRetry()
        #expect(!timer)
    }

    @Test("A successful send or session teardown resets the backoff and clears pending work")
    func reset() {
        var policy = WorkoutMirrorRetryPolicy()
        _ = policy.scheduleRetry()
        _ = policy.beginRetry()
        _ = policy.scheduleRetry()
        policy.reset()
        let cancelled = policy.beginRetry()
        #expect(!cancelled)
        let nextDelay = policy.scheduleRetry()
        #expect(nextDelay == 5)
    }
}
