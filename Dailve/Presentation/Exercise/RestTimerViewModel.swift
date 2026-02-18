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

    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard defaultDuration > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(defaultDuration)
    }

    func start(seconds: Int? = nil) {
        timerTask?.cancel()
        let duration = seconds ?? defaultDuration
        secondsRemaining = duration
        defaultDuration = duration
        isRunning = true

        timerTask = Task {
            while secondsRemaining > 0, !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    // Sleep interrupted (cancellation or system)
                    break
                }
                guard !Task.isCancelled else { break }
                secondsRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            isRunning = false
            completionCount += 1
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }

    func addTime(_ seconds: Int) {
        secondsRemaining += seconds
    }
}
