import SwiftUI
import WatchKit

/// Circular countdown rest timer shown between sets.
/// Plays `.notification` haptic when complete.
struct RestTimerView: View {
    let duration: TimeInterval
    let onComplete: (_ timerTotal: TimeInterval) -> Void
    let onSkip: (_ timerTotal: TimeInterval) -> Void
    /// Auto-estimated RPE for the just-completed set (nil = silent skip).
    var estimatedRPE: Double?
    /// Called only after a user confirms or adjusts RPE.
    var onRPEAdjusted: ((Double) -> Void)?

    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    /// Maximum total rest duration (including +30s additions).
    private static let maxDurationSeconds = 600
    /// Seconds before end to play warning haptic.
    private static let warningThresholdSeconds: TimeInterval = 10

    /// The absolute time when the timer should finish.
    @State private var targetDate: Date = .distantFuture
    /// Total seconds for progress calculation.
    @State private var totalSeconds: Int = 0
    /// Mutated each tick to force SwiftUI re-render.
    @State private var tick: Int = 0
    /// The running countdown task (cancelled on disappear).
    @State private var countdownTask: Task<Void, Never>?
    /// Whether the warning haptic has fired.
    @State private var didPlayWarning = false
    /// Local RPE value for adjustment (initialized from estimatedRPE).
    @State private var adjustedRPE: Double = 8.0
    @State private var showRPEInput = false
    @State private var showEndConfirmation = false
    @State private var hasConfirmedRPE = false
    @State private var pendingTimerCompletion = false
    @State private var didFinish = false

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(84, max(76, geometry.size.height * 0.50))
            let spacing = min(DS.Spacing.sm, max(DS.Spacing.xs, geometry.size.height * 0.025))

            ViewThatFits(in: .vertical) {
                timerContent(ringSize: ringSize, actionSpacing: spacing)

                ScrollView {
                    timerContent(ringSize: ringSize, actionSpacing: spacing)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerScreen)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showEndConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.negative)
                }
                .accessibilityLabel("End Workout")
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerEndButton)
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                didFinish = true
                cancelCountdown()
                workoutManager.end()
            }
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("watch-session-end-cancel")
        } message: {
            Text("Save and finish this workout?")
        }
        .sheet(isPresented: $showRPEInput, onDismiss: {
            if pendingTimerCompletion {
                pendingTimerCompletion = false
                timerFinished()
            }
        }) {
            rpeOverlay
                .padding(DS.Spacing.md)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("watch-rest-timer-rpe-sheet")
        }
        .onAppear {
            if let estimatedRPE {
                adjustedRPE = estimatedRPE
            }
            if targetDate == .distantFuture {
                startCountdown()
            } else if remainingSeconds == 0 {
                timerFinished()
            }
        }
        .onChange(of: workoutManager.isActive) { _, isActive in
            if !isActive { cancelCountdown() }
        }
        .onDisappear {
            if !workoutManager.isActive { cancelCountdown() }
        }
    }

    private func timerContent(ringSize: CGFloat, actionSpacing: CGFloat) -> some View {
        VStack(spacing: actionSpacing) {
            HStack(spacing: actionSpacing) {
                // Keep the complete m:ss value and heart rate inside the ring.
                ZStack {
                    Circle()
                        .stroke(.tertiary, lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(DS.Color.positive, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: tick)

                    VStack(spacing: DS.Spacing.xxs) {
                        Text(timeString)
                            .font(DS.Typography.countdownValue)
                            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerCountdown)

                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.metricHeartRate)
                            if workoutManager.heartRate > 0 {
                                Text(Int(workoutManager.heartRate).formattedWithSeparator)
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
                .frame(width: ringSize, height: ringSize)

                Button {
                    adjustedRPE = estimatedRPE ?? 8
                    showRPEInput = true
                } label: {
                    VStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "pencil")
                            .foregroundStyle(DS.Color.positive)
                        if let estimatedRPE {
                            Text("RPE \(RPELevel.format(estimatedRPE))")
                                .monospacedDigit()
                            if !hasConfirmedRPE {
                                Text("Suggested")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Rate RPE")
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(DS.Color.positive.opacity(DS.Opacity.light), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .accessibilityIdentifier(
                    estimatedRPE == nil
                        ? "watch-rest-timer-rpe-rate"
                        : WatchWorkoutSurfaceAccessibility.restTimerRPEBadge
                )
            }

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    addTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 64, minHeight: 37)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .disabled(totalSeconds + 30 > Self.maxDurationSeconds)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerAddTimeButton)

                Button {
                    didFinish = true
                    let total = TimeInterval(totalSeconds)
                    cancelCountdown()
                    onSkip(total)
                } label: {
                    Text("Skip")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 37)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.positive)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerSkipButton)
            }
        }
    }

    // MARK: - RPE Overlay

    private var rpeOverlay: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    let newValue = adjustedRPE - RPELevel.step
                    if RPELevel.range.contains(newValue) {
                        adjustedRPE = newValue
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption2.weight(.semibold))
                        .frame(minWidth: 32, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                VStack(spacing: 0) {
                    Text("RPE \(RPELevel.format(adjustedRPE))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(rpeColor)
                        .contentTransition(.numericText())
                    Text(RPELevel(value: adjustedRPE).displayLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Button {
                    let newValue = adjustedRPE + RPELevel.step
                    if RPELevel.range.contains(newValue) {
                        adjustedRPE = newValue
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.semibold))
                        .frame(minWidth: 32, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            Button("Confirm RPE") {
                onRPEAdjusted?(adjustedRPE)
                hasConfirmedRPE = true
                showRPEInput = false
                WKInterfaceDevice.current().play(.success)
            }
            .font(.caption2.weight(.semibold))
            .buttonStyle(.bordered)
            .accessibilityIdentifier("watch-rest-timer-rpe-confirm")
        }
    }

    private var rpeColor: Color {
        switch adjustedRPE {
        case ..<7.0: DS.Color.positive
        case 7.0..<8.0: DS.Color.caution
        case 8.0..<9.0: .orange
        default: DS.Color.negative
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
        return String(format: "%d:%02d", mins, remainder)
    }

    // MARK: - Countdown

    private func startCountdown() {
        let total = Int(min(max(duration, 0), TimeInterval(Self.maxDurationSeconds)))
        totalSeconds = total
        targetDate = Date().addingTimeInterval(TimeInterval(total))

        didPlayWarning = false
        didFinish = false
        countdownTask?.cancel()
        countdownTask = Task {
            while !Task.isCancelled {
                // P2: Reduce tick frequency when AOD is active
                let interval: Duration = isLuminanceReduced ? .seconds(5) : .seconds(1)
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                // Mutate @State to force view update
                tick += 1

                let remaining = targetDate.timeIntervalSinceNow
                // Warning haptic (fires once per countdown)
                if remaining <= Self.warningThresholdSeconds, remaining > 0, !didPlayWarning {
                    didPlayWarning = true
                    WKInterfaceDevice.current().play(.start)
                }

                if remaining <= 0 {
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
        // P3: Cap total duration to prevent overflow
        let newTotal = totalSeconds + seconds
        guard newTotal <= Self.maxDurationSeconds else { return }
        targetDate = targetDate.addingTimeInterval(TimeInterval(seconds))
        totalSeconds = newTotal
    }

    private func timerFinished() {
        guard !didFinish else { return }
        if showRPEInput {
            pendingTimerCompletion = true
            cancelCountdown()
            return
        }
        didFinish = true
        let total = TimeInterval(totalSeconds)
        cancelCountdown()
        WKInterfaceDevice.current().play(.notification)
        onComplete(total)
    }
}
