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
    var suggestedWeightKg: Double? = nil
    var onWeightEdited: (Double) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    @State private var lastHapticDate: Date = .distantPast
    @State private var showPreviousSets = false
    /// Stable Crown accumulator for duration (avoids Binding(get:set:) recreation per render).
    @State private var crownDurationDouble: Double = 1
    @State private var crownRepsDouble: Double = 10
    @FocusState private var isCrownFocused: Bool

    private var actionableSuggestedWeightKg: Double? {
        guard let suggestedWeightKg, suggestedWeightKg < weight else { return nil }
        return suggestedWeightKg
    }

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
        VStack {
            adaptiveInputLayout {
                VStack(spacing: DS.Spacing.sm) {
                    if inputType == .setsReps { addedWeightToggle }
                    weightSection
                    if let suggestedWeightKg = actionableSuggestedWeightKg {
                        Button {
                            weight = suggestedWeightKg
                            onWeightEdited(suggestedWeightKg)
                        } label: {
                            Text("Use \(suggestedWeightKg, specifier: "%.1f") kg")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Color.caution)
                        .background(DS.Color.caution.opacity(DS.Opacity.border), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .accessibilityIdentifier("watch-set-input-use-lighter-weight")
                    } else {
                        Divider()
                    }
                    repsSection
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation($weight, from: 0, through: 500, by: 0.5, sensitivity: .medium)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputScreen)
        .toolbar { sharedToolbar }
        .onChange(of: weight) { _, newValue in
            let clamped = min(max(newValue, 0), 500)
            if clamped != newValue { weight = clamped }
            onWeightEdited(clamped)
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
        VStack {
            adaptiveInputLayout {
                VStack(spacing: DS.Spacing.lg) {
                    if inputType == .setsReps { addedWeightToggle }
                    repsSection
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownRepsDouble,
            from: 1, through: Double(WatchSetInputPolicy.maximumEditableReps), by: 1, sensitivity: .medium
        )
        .accessibilityElement(children: .contain)
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
        VStack(spacing: DS.Spacing.lg) {
            durationSection
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation($crownDurationDouble, from: 0, through: 120, by: 1, sensitivity: .medium)
        .accessibilityElement(children: .contain)
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

    /// Touch scrolling is a fallback for large text; the Crown remains bound to the active value.
    private func adaptiveInputLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ViewThatFits(in: .vertical) {
            content()
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                content()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
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
                .accessibilityLabel(Text("Previous Sets"))
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
                if !enabled {
                    weight = 0
                    onWeightEdited(0)
                }
                usesAddedWeight = enabled
            }
        ))
            .font(DS.Typography.tileSubtitle)
            .tint(DS.Color.positive)
            .accessibilityIdentifier("watch-set-input-added-weight")
    }

    private var weightSection: some View {
        HStack(spacing: DS.Spacing.xs) {
            weightButton("-2.5", delta: -2.5)
            VStack(spacing: 0) {
                Text("\(weight, specifier: "%.1f")")
                    .font(DS.Typography.countdownValue)
                    .foregroundStyle(DS.Color.positive)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kg")
                    .font(DS.Typography.metricLabel)
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier(
            delta < 0
                ? WatchWorkoutSurfaceAccessibility.setInputWeightDecrementButton
                : WatchWorkoutSurfaceAccessibility.setInputWeightIncrementButton
        )
    }

    // MARK: - Reps Section

    private var repsSection: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button {
                if reps > WatchSetInputPolicy.minimumReps {
                    reps -= 1
                    playDebouncedHaptic()
                }
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputRepsDecrementButton)

            VStack(spacing: 0) {
                Text("\(reps)")
                    .font(DS.Typography.countdownValue)
                    .foregroundStyle(DS.Color.positive)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("reps")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                if reps < WatchSetInputPolicy.maximumEditableReps {
                    reps += 1
                    playDebouncedHaptic()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputRepsIncrementButton)
        }
    }

    // MARK: - Duration Section

    private var durationSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("\(durationMinutes)")
                .font(DS.Typography.primaryMetric)
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Previous Sets Detail

    private var previousSetsDetail: some View {
        List {
            Section {
                ForEach(previousSets, id: \.setNumber) { set in
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack {
                            Text("Set \(set.setNumber)")
                                .font(DS.Typography.tileSubtitle)
                                .foregroundStyle(DS.Color.positive)
                            Spacer(minLength: DS.Spacing.xs)
                            if let rpe = set.rpe {
                                Text("RPE \(RPELevel.format(rpe))")
                                    .font(DS.Typography.metricLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: DS.Spacing.sm) {
                            if let duration = set.duration, duration > 0 {
                                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                            }
                            if let weight = set.weight, weight > 0 {
                                Text("\(weight, specifier: "%.1f")kg")
                            }
                            if let reps = set.reps, reps > 0 {
                                Text("\u{00d7}\(reps)")
                            }
                        }
                        .font(DS.Typography.tileSubtitle.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                    .accessibilityElement(children: .combine)
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
