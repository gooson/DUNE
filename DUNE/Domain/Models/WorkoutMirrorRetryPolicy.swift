/// Back off while a workout is active, including when the phone stays in the background.
struct WorkoutMirrorRetryPolicy {
    private var nextDelaySeconds = 5
    private var retryScheduled = false

    /// The send and disconnect callbacks can report the same failure.
    mutating func scheduleRetry() -> Int? {
        guard !retryScheduled else { return nil }
        retryScheduled = true
        let delay = nextDelaySeconds
        nextDelaySeconds = min(delay * 2, 120)
        return delay
    }

    /// Both the timer and a reachability change can claim the pending retry.
    mutating func beginRetry() -> Bool {
        guard retryScheduled else { return false }
        retryScheduled = false
        return true
    }

    mutating func reset() {
        self = Self()
    }
}
