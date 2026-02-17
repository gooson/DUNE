import SwiftUI
import WatchKit

/// Circular countdown rest timer shown between sets.
/// Plays `.notification` haptic when complete.
struct RestTimerView: View {
    let duration: TimeInterval
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void

    @Environment(WorkoutManager.self) private var workoutManager

    /// The absolute time when the timer should finish.
    @State private var targetDate: Date = .distantFuture
    /// Total seconds for progress calculation.
    @State private var totalSeconds: Int = 0
    /// Mutated each tick to force SwiftUI re-render.
    @State private var tick: Int = 0
    /// The running countdown task (cancelled on disappear).
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 6) {
            Text("Rest")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Circular gauge
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: tick)

                VStack(spacing: 2) {
                    Text(timeString)
                        .font(.system(.title2, design: .rounded).monospacedDigit().weight(.bold))

                    // HR display during rest
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                        if workoutManager.heartRate > 0 {
                            Text("\(Int(workoutManager.heartRate))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("--")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .frame(width: 100, height: 100)

            // +30s / Skip / End buttons
            HStack(spacing: 10) {
                Button {
                    addTime(30)
                } label: {
                    Text("+30s")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button {
                    cancelCountdown()
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button(role: .destructive) {
                    cancelCountdown()
                    onEnd()
                } label: {
                    Text("End")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            cancelCountdown()
        }
    }

    // MARK: - Computed

    private var remainingSeconds: Int {
        // `tick` dependency ensures SwiftUI re-evaluates on each tick
        _ = tick
        let remaining = Int(targetDate.timeIntervalSinceNow.rounded(.up))
        return Swift.max(remaining, 0)
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var timeString: String {
        let secs = remainingSeconds
        let mins = secs / 60
        let remainder = secs % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, remainder)
        }
        return "\(secs)"
    }

    // MARK: - Countdown

    private func startCountdown() {
        let total = Int(min(max(duration, 0), 600))
        totalSeconds = total
        targetDate = Date().addingTimeInterval(TimeInterval(total))

        countdownTask?.cancel()
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                // Mutate @State to force view update
                tick += 1
                if targetDate.timeIntervalSinceNow <= 0 {
                    timerFinished()
                    return
                }
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func addTime(_ seconds: Int) {
        targetDate = targetDate.addingTimeInterval(TimeInterval(seconds))
        totalSeconds += seconds
    }

    private func timerFinished() {
        cancelCountdown()
        WKInterfaceDevice.current().play(.notification)
        onComplete()
    }
}
