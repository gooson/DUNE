import SwiftUI
import WatchKit

/// Dedicated sheet for weight/reps input with Digital Crown support.
/// Crown controls weight (scroll = touch), layout adapts to any watch size.
/// Previous set history accessible via toolbar button to keep weight input at top.
struct SetInputSheet: View {
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var rpe: Double?
    /// Previously completed sets for the current exercise (newest last)
    var previousSets: [CompletedSetData] = []
    @Environment(\.dismiss) private var dismiss

    @State private var lastHapticDate: Date = .distantPast
    @State private var showPreviousSets = false
    @FocusState private var isWeightCrownFocused: Bool

    var body: some View {
        if showPreviousSets {
            previousSetsDetail
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputPreviousSetsScreen)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { showPreviousSets = false } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputPreviousSetsBackButton)
                    }
                }
        } else {
            VStack(spacing: DS.Spacing.lg) {
                // Weight — large display + crown + ±2.5 buttons
                weightSection

                Divider()

                // Reps — inline ± row
                repsSection

                Divider()

                // RPE — visible in the set input context instead of a separate flow
                rpeSection
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .focusable(true)
            .focused($isWeightCrownFocused)
            .digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputScreen)
            .toolbar {
                if !previousSets.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showPreviousSets = true
                        } label: {
                            Image(systemName: "list.bullet.clipboard")
                        }
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputPreviousSetsButton)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputDoneButton)
                }
            }
            .onChange(of: weight) { _, newValue in
                let clamped = min(max(newValue, 0), 500)
                if clamped != newValue { weight = clamped }
            }
            .onChange(of: reps) { _, newValue in
                let clamped = min(
                    max(newValue, WatchSetInputPolicy.minimumReps),
                    WatchSetInputPolicy.maximumEditableReps
                )
                if clamped != newValue {
                    reps = clamped
                }
            }
            .onAppear {
                isWeightCrownFocused = true
                reps = WatchSetInputPolicy.resolvedInitialReps(
                    lastSetReps: reps,
                    entryDefaultReps: WatchSetInputPolicy.defaultReps
                )
            }
            .onDisappear {
                isWeightCrownFocused = false
            }
        }
    }

    // MARK: - Weight

    private var weightSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("\(weight, specifier: "%.1f")")
                .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(DS.Color.positive)
                .contentTransition(.numericText())

            Text("kg")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            // ± buttons for quick jumps (crown for fine tuning)
            HStack(spacing: DS.Spacing.md) {
                weightButton("-2.5", delta: -2.5)
                weightButton("+2.5", delta: 2.5)
            }
        }
    }

    private func weightButton(_ label: String, delta: Double) -> some View {
        Button {
            let newValue = weight + delta
            if (0...500).contains(newValue) {
                weight = newValue
                playDebouncedHaptic()
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .accessibilityIdentifier(
            delta < 0
                ? WatchWorkoutSurfaceAccessibility.setInputWeightDecrementButton
                : WatchWorkoutSurfaceAccessibility.setInputWeightIncrementButton
        )
    }

    // MARK: - Reps

    private var repsSection: some View {
        HStack {
            Button {
                if reps > WatchSetInputPolicy.minimumReps {
                    reps -= 1
                    playDebouncedHaptic()
                }
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputRepsDecrementButton)

            Spacer()

            VStack(spacing: 0) {
                Text("\(reps)")
                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(DS.Color.positive)
                    .contentTransition(.numericText())
                Text("reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if reps < 100 {
                    reps += 1
                    playDebouncedHaptic()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputRepsIncrementButton)
        }
    }

    // MARK: - RPE

    private var rpeSection: some View {
        WatchSetRPEPickerView(rpe: $rpe)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputRPEControl)
    }

    // MARK: - Previous Sets (Push Destination)

    private var previousSetsDetail: some View {
        List {
            Section {
                ForEach(previousSets, id: \.setNumber) { set in
                    HStack(spacing: DS.Spacing.sm) {
                        Text("Set \(set.setNumber)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 36, alignment: .leading)

                        if let w = set.weight, w > 0 {
                            Text("\(w, specifier: "%.1f")kg")
                                .font(.caption2.monospacedDigit())
                        }

                        if let r = set.reps, r > 0 {
                            Text("\u{00d7}\(r)")
                                .font(.caption2.monospacedDigit())
                        }

                        Spacer()

                        if let rpe = set.rpe {
                            Text("RPE \(rpe, specifier: rpe.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f")")
                                .font(.caption2)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    .accessibilityIdentifier(
                        WatchWorkoutSurfaceAccessibility.setInputPreviousSetRow(set.setNumber)
                    )
                }
            } header: {
                Text("Previous Sets")
            }
        }
    }

    // MARK: - Haptic

    private func playDebouncedHaptic() {
        let now = Date()
        guard now.timeIntervalSince(lastHapticDate) >= 0.1 else { return }
        lastHapticDate = now
        WKInterfaceDevice.current().play(.click)
    }
}
