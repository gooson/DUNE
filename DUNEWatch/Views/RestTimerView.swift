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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            let ringSize = min(136, geometry.size.width - DS.Spacing.xl * 2,
                               max(96, geometry.size.height - 44 - DS.Spacing.md * 2))

            ViewThatFits(in: .vertical) {
                timerContent(ringSize: ringSize)

                ScrollView {
                    timerContent(ringSize: ringSize)
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
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
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

    private func timerContent(ringSize: CGFloat) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                if !isLuminanceReduced {
                    Circle()
                        .stroke(theme.metricActivity.opacity(DS.Opacity.overlay), lineWidth: 7)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(theme.metricActivity, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 1), value: tick)
                }

                VStack(spacing: DS.Spacing.xs) {
                    Text(timeString)
                        .font(.system(size: min(36, ringSize * 0.3), weight: .bold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerCountdown)

                    heartRateLabel
                }
                .frame(width: ringSize - DS.Spacing.xl * 2)
            }
            .frame(width: ringSize, height: ringSize)

            HStack(spacing: DS.Spacing.xs) {
                Button {
                    addTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption2.weight(.semibold))
                        .frame(minWidth: 46, maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .disabled(totalSeconds + 30 > Self.maxDurationSeconds)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerAddTimeButton)

                rpeButton

                Button {
                    didFinish = true
                    let total = TimeInterval(totalSeconds)
                    cancelCountdown()
                    onSkip(total)
                } label: {
                    Text("Skip")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(minWidth: 50, maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isLuminanceReduced ? Color.primary : Color.black)
                .background(isLuminanceReduced ? Color.clear : theme.metricActivity,
                            in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.restTimerSkipButton)
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    private var heartRateLabel: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: "heart.fill")
                .accessibilityHidden(true)
            if workoutManager.heartRate > 0 {
                Text("\(Int(workoutManager.heartRate).formattedWithSeparator) bpm")
                    .monospacedDigit()
            } else {
                Text("--")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(theme.metricHeartRate)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart Rate")
        .accessibilityValue(workoutManager.heartRate > 0
            ? Text("\(Int(workoutManager.heartRate).formattedWithSeparator) bpm")
            : Text("Not measured"))
    }

    private var rpeButton: some View {
        Button {
            adjustedRPE = hasConfirmedRPE ? adjustedRPE : (estimatedRPE ?? 8)
            showRPEInput = true
        } label: {
            VStack(spacing: 0) {
                if hasConfirmedRPE {
                    Text("RPE")
                        .font(DS.Typography.tinyLabel)
                    Text(RPELevel.format(adjustedRPE))
                        .monospacedDigit()
                } else if let estimatedRPE {
                    Text("Suggested")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(RPELevel.format(estimatedRPE))
                        .monospacedDigit()
                } else {
                    Text("RPE")
                        .font(DS.Typography.tinyLabel)
                    Text("Record")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 46, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityLabel(rpeButtonAccessibilityLabel)
        .accessibilityIdentifier(
            estimatedRPE == nil && !hasConfirmedRPE
                ? "watch-rest-timer-rpe-rate"
                : WatchWorkoutSurfaceAccessibility.restTimerRPEBadge
        )
    }

    private var rpeButtonAccessibilityLabel: Text {
        if hasConfirmedRPE {
            Text("RPE \(RPELevel.format(adjustedRPE))")
        } else if let estimatedRPE {
            Text("RPE \(RPELevel.format(estimatedRPE))")
        } else {
            Text("Rate RPE")
        }
    }

    // MARK: - RPE Overlay

    private var rpeOverlay: some View {
        ScrollView {
            HStack(spacing: DS.Spacing.xs) {
                Button {
                    let newValue = adjustedRPE - RPELevel.step
                    if RPELevel.range.contains(newValue) {
                        adjustedRPE = newValue
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(.quaternary, in: Circle())
                .accessibilityLabel("Decrease RPE")
                .disabled(adjustedRPE <= RPELevel.range.lowerBound)

                VStack(spacing: DS.Spacing.xxs) {
                    Text(RPELevel.format(adjustedRPE))
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(rpeColor)
                        .contentTransition(.numericText())
                    Text(RPELevel(value: adjustedRPE).displayLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("RPE")
                .accessibilityValue(Text(RPELevel.format(adjustedRPE)))

                Button {
                    let newValue = adjustedRPE + RPELevel.step
                    if RPELevel.range.contains(newValue) {
                        adjustedRPE = newValue
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(.quaternary, in: Circle())
                .accessibilityLabel("Increase RPE")
                .disabled(adjustedRPE >= RPELevel.range.upperBound)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.xs)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                onRPEAdjusted?(adjustedRPE)
                hasConfirmedRPE = true
                showRPEInput = false
                WKInterfaceDevice.current().play(.success)
            } label: {
                Text("Confirm RPE")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(theme.metricActivity, in: Capsule())
            .accessibilityIdentifier("watch-rest-timer-rpe-confirm")
            .padding(.top, DS.Spacing.xs)
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
