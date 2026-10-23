/// Allows one delayed retry per mirroring outage. A new connection can reopen
/// an exhausted outage, while success prepares the next independent outage.
struct WorkoutMirrorRetryPolicy {
    private enum State {
        case ready
        case scheduled
        case retrying
        case exhausted
    }

    private var state: State = .ready

    var isRetryScheduled: Bool { state == .scheduled }

    /// Returns true only when a new delayed retry should be scheduled.
    mutating func recordFailure() -> Bool {
        switch state {
        case .ready:
            state = .scheduled
            return true
        case .retrying:
            state = .exhausted
            return false
        case .scheduled, .exhausted:
            return false
        }
    }

    /// Marks the single scheduled retry as underway.
    mutating func beginRetry() -> Bool {
        guard state == .scheduled else { return false }
        state = .retrying
        return true
    }

    mutating func recordSuccess() {
        state = .ready
    }

    /// Reopens only an exhausted outage after an actual unreachable-to-reachable change.
    mutating func recordReconnect() -> Bool {
        guard state == .exhausted else { return false }
        state = .scheduled
        return true
    }

    mutating func reset() {
        state = .ready
    }
}
