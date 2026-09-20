import SwiftUI
import WatchKit

/// Dedicated sheet for set input with Digital Crown support.
/// Adapts input fields based on exercise inputType:
/// - setsRepsWeight: weight (crown) + reps
/// - setsReps: reps only (crown controls reps)
/// - durationIntensity: minutes (crown controls minutes)
struct SetInputSheet: View {
    let inputType: ExerciseInputType
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var durationMinutes: Int
    @Binding var usesAddedWeight: Bool
    /// Previously completed sets for the current exercise (newest last)
    var previousSets: [CompletedSetData] = []
    @Environment(\.dismiss) private var dismiss

    @State private var lastHapticDate: Date = .distantPast
    @State private var showPreviousSets = false
    /// Stable Crown accumulator for duration (avoids Binding(get:set:) recreation per render).
    @State private var crownDurationDouble: Double = 1
    @State private var crownRepsDouble: Double = 10
    @FocusState private var isCrownFocused: Bool

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
            mainContent
        }
    }

    // MARK: - Main Content (by inputType)

    @ViewBuilder
    private var mainContent: some View {
        switch inputType {
        case .durationIntensity:
            durationContent
        case .setsReps:
            if usesAddedWeight { weightRepsContent } else { repsOnlyContent }
        case .roundsBased:
            repsOnlyContent
        case .setsRepsWeight, .durationDistance:
            weightRepsContent
        }
    }

    // MARK: - Weight + Reps

    private var weightRepsContent: some View {
        VStack(spacing: DS.Spacing.sm) {
            if inputType == .setsReps { addedWeightToggle }
            weightSection
            Divider()
            repsSection
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation($weight, from: 0, through: 500, by: 0.5, sensitivity: .medium)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputScreen)
        .toolbar { sharedToolbar }
        .onChange(of: weight) { _, newValue in
            let clamped = min(max(newValue, 0), 500)
            if clamped != newValue { weight = clamped }
        }
        .onChange(of: reps) { _, newValue in
            let clamped = min(
                max(newValue, WatchSetInputPolicy.minimumReps),
                WatchSetInputPolicy.maximumEditableReps
            )
            if clamped != newValue { reps = clamped }
        }
        .onAppear {
            isCrownFocused = true
            reps = WatchSetInputPolicy.resolvedInitialReps(
                lastSetReps: reps,
                entryDefaultReps: WatchSetInputPolicy.defaultReps
            )
        }
        .onDisappear { isCrownFocused = false }
    }

    // MARK: - Reps Only (setsReps / bodyweight)

    private var repsOnlyContent: some View {
        VStack(spacing: DS.Spacing.sm) {
            if inputType == .setsReps { addedWeightToggle }
            repsSection
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownRepsDouble,
            from: 1, through: Double(WatchSetInputPolicy.maximumEditableReps), by: 1, sensitivity: .medium
        )
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputScreen)
        .toolbar { sharedToolbar }
        .onChange(of: crownRepsDouble) { _, value in
            reps = max(1, min(WatchSetInputPolicy.maximumEditableReps, Int(value.rounded())))
        }
        .onChange(of: reps) { _, newValue in
            let clamped = min(
                max(newValue, WatchSetInputPolicy.minimumReps),
                WatchSetInputPolicy.maximumEditableReps
            )
            if clamped != newValue { reps = clamped }
            crownRepsDouble = Double(clamped)
        }
        .onAppear {
            isCrownFocused = true
            reps = WatchSetInputPolicy.resolvedInitialReps(
                lastSetReps: reps,
                entryDefaultReps: WatchSetInputPolicy.defaultReps
            )
            crownRepsDouble = Double(reps)
        }
        .onDisappear { isCrownFocused = false }
    }

    // MARK: - Duration (durationIntensity / plank, wall sit, etc.)

    private var durationContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                durationSection
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation($crownDurationDouble, from: 0, through: 120, by: 1, sensitivity: .medium)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputScreen)
        .toolbar { sharedToolbar }
        .onAppear {
            crownDurationDouble = Double(durationMinutes)
            isCrownFocused = true
        }
        .onChange(of: crownDurationDouble) { _, newValue in
            let clamped = max(0, min(120, Int(newValue.rounded())))
            if clamped != durationMinutes { durationMinutes = clamped }
        }
        .onDisappear { isCrownFocused = false }
    }

    // MARK: - Shared Toolbar

    @ToolbarContentBuilder
    private var sharedToolbar: some ToolbarContent {
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

    // MARK: - Weight Section

    private var addedWeightToggle: some View {
        Toggle("Added Weight", isOn: Binding(
            get: { usesAddedWeight },
            set: { enabled in
                if !enabled { weight = 0 }
                usesAddedWeight = enabled
            }
        ))
            .accessibilityIdentifier("watch-set-input-added-weight")
    }

    private var weightSection: some View {
        HStack(spacing: DS.Spacing.xs) {
            weightButton("-2.5", delta: -2.5)
            VStack(spacing: 0) {
                Text("\(weight, specifier: "%.1f")")
                    .font(.system(.title3, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(DS.Color.positive)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            weightButton("+2.5", delta: 2.5)
        }
    }

    private func weightButton(_ label: String, delta: Double) -> some View {
        Button {
            let newValue = min(500, max(0, weight + delta))
            if (0...500).contains(newValue) {
                weight = newValue
                playDebouncedHaptic()
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .accessibilityIdentifier(
            delta < 0
                ? WatchWorkoutSurfaceAccessibility.setInputWeightDecrementButton
                : WatchWorkoutSurfaceAccessibility.setInputWeightIncrementButton
        )
    }

    // MARK: - Reps Section

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
                if reps < WatchSetInputPolicy.maximumEditableReps {
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

    // MARK: - Duration Section

    private var durationSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("\(durationMinutes)")
                .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(DS.Color.positive)
                .contentTransition(.numericText())

            Text(String(localized: "min"))
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.md) {
                durationButton("-1", delta: -1)
                durationButton("+1", delta: 1)
            }
        }
    }

    private func durationButton(_ label: String, delta: Int) -> some View {
        Button {
            let newValue = durationMinutes + delta
            if (0...120).contains(newValue) {
                durationMinutes = newValue
                crownDurationDouble = Double(newValue)
                playDebouncedHaptic()
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    // MARK: - Previous Sets Detail

    private var previousSetsDetail: some View {
        List {
            Section {
                ForEach(previousSets, id: \.setNumber) { set in
                    HStack(spacing: DS.Spacing.sm) {
                        Text("Set \(set.setNumber)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 36, alignment: .leading)

                        if let d = set.duration, d > 0 {
                            Text(Duration.seconds(d).formatted(.time(pattern: .minuteSecond)))
                                .font(.caption2.monospacedDigit())
                        }
                        Group {
                            if let w = set.weight, w > 0 {
                                Text("\(w, specifier: "%.1f")kg")
                                    .font(.caption2.monospacedDigit())
                            }

                            if let r = set.reps, r > 0 {
                                Text("\u{00d7}\(r)")
                                    .font(.caption2.monospacedDigit())
                            }
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
