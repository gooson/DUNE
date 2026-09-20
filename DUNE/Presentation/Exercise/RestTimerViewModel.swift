import Foundation
import Observation

@Observable
@MainActor
final class RestTimerViewModel {
    var secondsRemaining: Int = 0
    var isRunning: Bool = false
    var defaultDuration: Int = 30
    var completionCount: Int = 0

    private var timerTask: Task<Void, Never>?
    private(set) var endDate: Date?
    @ObservationIgnored private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard defaultDuration > 0 else { return 0 }
        return min(1, max(0, 1.0 - Double(secondsRemaining) / Double(defaultDuration)))
    }

    func start(seconds: Int? = nil) {
        let duration = min(3600, max(0, seconds ?? defaultDuration))
        restore(endDate: now().addingTimeInterval(TimeInterval(duration)), totalDuration: duration)
    }

    /// Recompute from the deadline after background suspension instead of counting wakeups.
    func restore(endDate: Date, totalDuration: Int) {
        stop()
        defaultDuration = min(3600, max(0, totalDuration))
        let currentDate = now()
        let remaining = endDate.timeIntervalSince(currentDate)
        self.endDate = currentDate.addingTimeInterval(
            remaining.isFinite ? min(Double(defaultDuration), max(0, remaining)) : 0
        )
        isRunning = true
        refresh()
        guard isRunning else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled, let self, self.isRunning else { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        guard isRunning, let endDate else { return }
        let remaining = endDate.timeIntervalSince(now())
        secondsRemaining = remaining.isFinite ? Int(min(3600, max(0, remaining.rounded(.up)))) : 0
        if secondsRemaining == 0 {
            stop()
            completionCount += 1
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
        endDate = nil
    }

    func addTime(_ seconds: Int) {
        guard isRunning, let deadline = endDate else { return }
        refresh()
        guard isRunning else { return }
        let adjustment = min(3600 - defaultDuration, max(-secondsRemaining, seconds))
        defaultDuration += adjustment
        endDate = deadline.addingTimeInterval(TimeInterval(adjustment))
        refresh()
    }
}
