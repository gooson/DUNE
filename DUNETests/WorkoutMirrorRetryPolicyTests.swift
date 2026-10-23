import Testing
@testable import DUNE

@Suite("WorkoutMirrorRetryPolicy")
struct WorkoutMirrorRetryPolicyTests {
    @Test("Duplicate failures schedule only one retry")
    func duplicateFailure() {
        var policy = WorkoutMirrorRetryPolicy()
        let transition1 = policy.recordFailure()
        #expect(transition1)
        let transition2 = policy.recordFailure()
        #expect(!transition2)
        #expect(policy.isRetryScheduled)
        let transition3 = policy.beginRetry()
        #expect(transition3)
        #expect(!policy.isRetryScheduled)
        let transition4 = policy.beginRetry()
        #expect(!transition4)
    }

    @Test("A failed retry exhausts the current outage")
    func exhaustedRetry() {
        var policy = WorkoutMirrorRetryPolicy()
        let transition5 = policy.recordFailure()
        #expect(transition5)
        let transition6 = policy.beginRetry()
        #expect(transition6)
        let transition7 = policy.recordFailure()
        #expect(!transition7)
        let transition8 = policy.recordFailure()
        #expect(!transition8)
        let transition9 = policy.beginRetry()
        #expect(!transition9)
    }

    @Test("Success permits one retry for a later outage")
    func successResetsBudget() {
        var policy = WorkoutMirrorRetryPolicy()
        let transition10 = policy.recordFailure()
        #expect(transition10)
        let transition11 = policy.beginRetry()
        #expect(transition11)
        policy.recordSuccess()
        let transition12 = policy.recordFailure()
        #expect(transition12)
    }

    @Test("A new session resets an exhausted policy")
    func newSession() {
        var policy = WorkoutMirrorRetryPolicy()
        let transition13 = policy.recordFailure()
        #expect(transition13)
        let transition14 = policy.beginRetry()
        #expect(transition14)
        let transition15 = policy.recordFailure()
        #expect(!transition15)
        policy.reset()
        let transition16 = policy.recordFailure()
        #expect(transition16)
    }

    @Test("Reconnect reopens only an exhausted outage")
    func reconnectOnlyWhenExhausted() {
        var policy = WorkoutMirrorRetryPolicy()
        let transition17 = policy.recordReconnect()
        #expect(!transition17)
        let transition18 = policy.recordFailure()
        #expect(transition18)
        let transition19 = policy.recordReconnect()
        #expect(!transition19)
        let transition20 = policy.beginRetry()
        #expect(transition20)
        let transition21 = policy.recordFailure()
        #expect(!transition21)
        let transition22 = policy.recordReconnect()
        #expect(transition22)
        let transition23 = policy.recordReconnect()
        #expect(!transition23)
        let transition24 = policy.beginRetry()
        #expect(transition24)
    }
}
