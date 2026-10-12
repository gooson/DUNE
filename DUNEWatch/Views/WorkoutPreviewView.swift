import SwiftUI
import WatchKit

/// Pre-workout confirmation screen.
/// Strength: shows exercise list + Start button.
/// Cardio (single durationDistance exercise): shows cardio session start choices.
struct WorkoutPreviewView: View {
    let snapshot: WorkoutSessionTemplate
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityManager.self) private var connectivity
    @Environment(\.appTheme) private var theme

    @State private var isStarting = false
    @State private var isReordering = false
    @State private var errorMessage: String?
    @State private var lastCardioWasOutdoor = false
    #if DEBUG
    @State private var didInjectUITestCardioStartFailure = false
    #endif
    @State private var selectedLevel: Int = 5
    @FocusState private var levelFocused: Bool
    /// Mutable copy of entries for pre-workout reordering (original template unchanged).
    @State private var reorderedEntries: [TemplateEntry]

    init(snapshot: WorkoutSessionTemplate) {
        self.snapshot = snapshot
        _reorderedEntries = State(initialValue: snapshot.entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let cardioType = resolvedCardioType {
                cardioStartContent(activityType: cardioType)
            } else {
                strengthStartContent
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle(snapshot.name)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewScreen)
        .toolbar {
            if resolvedCardioType == nil && reorderedEntries.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isReordering.toggle()
                    } label: {
                        Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isReordering ? String(localized: "Done") : String(localized: "Reorder Exercises"))
                    .accessibilityIdentifier("watch-workout-preview-reorder")
                }
            }
        }
    }

    // MARK: - Cardio Type Resolution

    /// Returns the WorkoutActivityType if this is a single-exercise cardio workout.
    /// Uses Domain-level `resolveCardioActivity` with inputType guard to avoid
    /// false positives such as `walking-lunge` being interpreted as walking cardio.
    private var resolvedCardioType: WorkoutActivityType? {
        guard snapshot.entries.count == 1 else { return nil }
        let entry = snapshot.entries[0]
        let inputType = resolvedInputType(for: entry)
        return WorkoutActivityType.resolveCardioActivity(
            from: entry.exerciseDefinitionID,
            name: entry.exerciseName,
            inputTypeRaw: inputType
        )
    }

    private var resolvedCardioSecondaryUnit: CardioSecondaryUnit? {
        guard snapshot.entries.count == 1 else { return nil }
        let entry = snapshot.entries[0]
        guard let rawValue = resolvedCardioSecondaryUnitRaw(for: entry) else {
            return nil
        }
        return CardioSecondaryUnit(rawValue: rawValue)
    }

    /// Resolves input type from the synced watch library, then falls back to
    /// persisted template metadata so custom cardio still launches correctly.
    private func resolvedInputType(for entry: TemplateEntry) -> String? {
        TemplateExerciseProfile.normalizedInputTypeRaw(
            connectivity.exerciseInfo(for: entry.exerciseDefinitionID)?.inputType ?? entry.inputTypeRaw
        )
    }

    private func resolvedCardioSecondaryUnitRaw(for entry: TemplateEntry) -> String? {
        connectivity.exerciseInfo(for: entry.exerciseDefinitionID)?.cardioSecondaryUnit
            ?? entry.cardioSecondaryUnitRaw
    }

    // MARK: - Cardio Start

    private func cardioStartContent(activityType: WorkoutActivityType) -> some View {
        let cardioUnit = resolvedCardioSecondaryUnit ?? fallbackCardioSecondaryUnit(for: activityType)
        let supportsOutdoor = cardioUnit?.usesDistanceField == true && cardioUnit?.isIndoorOnly != true

        return VStack(spacing: DS.Spacing.sm) {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    cardioHeader(activityType: activityType, iconSize: 28, spacing: DS.Spacing.md)

                    if let errorMessage {
                        startErrorNotice(errorMessage)
                            .padding(.horizontal, DS.Spacing.lg)
                    }

                    if let cardioUnit, cardioUnit.supportsMachineLevel,
                       let range = cardioUnit.machineLevelRange {
                        machineLevelPicker(range: range)
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .scrollBounceBehavior(.basedOnSize)

            cardioActionButtons(
                activityType: activityType,
                cardioUnit: cardioUnit,
                supportsOutdoor: supportsOutdoor
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xs)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardio)
    }

    private func cardioHeader(
        activityType: WorkoutActivityType,
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(spacing: spacing) {
            Image(systemName: activityType.iconName)
                .font(.system(size: iconSize))
                .foregroundStyle(theme.sandColor)
                .frame(width: 36, height: 40)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(LocalizedStringKey(activityType.typeName))
                    .font(DS.Typography.exerciseName)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if errorMessage != nil {
                    Text(lastCardioWasOutdoor ? String(localized: "Outdoor") : String(localized: "Indoor"))
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func cardioActionButtons(
        activityType: WorkoutActivityType,
        cardioUnit: CardioSecondaryUnit?,
        supportsOutdoor: Bool
    ) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            if supportsOutdoor {
                Button {
                    startCardio(activityType: activityType, isOutdoor: false, secondaryUnit: cardioUnit)
                } label: {
                    cardioButtonLabel(
                        errorMessage != nil && !lastCardioWasOutdoor
                            ? String(localized: "Retry") : String(localized: "Indoor"),
                        systemImage: errorMessage != nil && !lastCardioWasOutdoor
                            ? "arrow.clockwise" : "building.fill"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isStarting)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardioIndoorButton)
            } else {
                Button {
                    startCardio(activityType: activityType, isOutdoor: false, secondaryUnit: cardioUnit)
                } label: {
                    cardioButtonLabel(
                        errorMessage != nil ? String(localized: "Retry") : String(localized: "Indoor"),
                        systemImage: errorMessage != nil ? "arrow.clockwise" : "building.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentColor)
                .disabled(isStarting)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardioIndoorButton)
            }

            if supportsOutdoor {
                Button {
                    startCardio(activityType: activityType, isOutdoor: true, secondaryUnit: cardioUnit)
                } label: {
                    Label(
                        errorMessage != nil && lastCardioWasOutdoor
                            ? String(localized: "Retry") : String(localized: "Outdoor"),
                        systemImage: errorMessage != nil && lastCardioWasOutdoor
                            ? "arrow.clockwise" : "sun.max.fill"
                    )
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentColor)
                .disabled(isStarting)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardioOutdoorButton)
            }
        }
    }

    private func cardioButtonLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            if isStarting {
                ProgressView()
                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStarting)
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func startCardio(
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        secondaryUnit: CardioSecondaryUnit?
    ) {
        guard !isStarting else { return }
        isStarting = true
        errorMessage = nil
        lastCardioWasOutdoor = isOutdoor

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-force-cardio-start-error"),
           !didInjectUITestCardioStartFailure {
            didInjectUITestCardioStartFailure = true
            isStarting = false
            errorMessage = String(localized: "Could not start workout. Please try again.")
            return
        }
        #endif

        let level: Int? = secondaryUnit?.supportsMachineLevel == true ? selectedLevel : nil

        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startCardioSession(
                    activityType: activityType,
                    isOutdoor: isOutdoor,
                    secondaryUnit: secondaryUnit,
                    initialLevel: level
                )
                WKInterfaceDevice.current().play(.success)
                isStarting = false
            } catch {
                isStarting = false
                presentStartError(error)
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func fallbackCardioSecondaryUnit(for activityType: WorkoutActivityType) -> CardioSecondaryUnit? {
        switch activityType {
        case .swimming, .rowing:
            return .meters
        case .stairClimbing, .stairStepper:
            return .floors
        case .jumpRope:
            return .count
        case .elliptical, .stepTraining, .mixedCardio, .crossTraining, .highIntensityIntervalTraining:
            return .timeOnly
        default:
            return activityType.isDistanceBased ? .km : nil
        }
    }

    // MARK: - Machine Level Picker

    private func machineLevelPicker(range: ClosedRange<Int>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                if selectedLevel > range.lowerBound {
                    selectedLevel -= 1
                }
            } label: {
                Image(systemName: "minus")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(selectedLevel <= range.lowerBound)
            .accessibilityLabel("Decrease Level")
            .accessibilityIdentifier("watch-workout-preview-level-decrease")

            VStack(spacing: 0) {
                Text("Level")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)

                Text("\(selectedLevel)")
                    .font(DS.Typography.secondaryMetric)
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("watch-workout-preview-level-value")
            }
            .frame(minWidth: 36)

            Button {
                if selectedLevel < range.upperBound {
                    selectedLevel += 1
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentColor)
            .disabled(selectedLevel >= range.upperBound)
            .accessibilityLabel("Increase Level")
            .accessibilityIdentifier("watch-workout-preview-level-increase")
        }
        .focusable(true)
        .focused($levelFocused)
        .digitalCrownRotation(
            detent: $selectedLevel,
            from: range.lowerBound,
            through: range.upperBound,
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            levelFocused = true
        }
    }

    // MARK: - Strength Start

    private var strengthStartContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    if let errorMessage {
                        startErrorNotice(errorMessage)
                            .listRowBackground(Color.clear)
                            .id("start-error")
                    }
                    Section {
                        ForEach(Array(reorderedEntries.enumerated()), id: \.element.id) { index, entry in
                            VStack(spacing: DS.Spacing.xs) {
                                HStack(spacing: DS.Spacing.sm) {
                                    WorkoutExerciseIcon(
                                        exerciseID: entry.exerciseDefinitionID,
                                        name: entry.exerciseName,
                                        inputType: resolvedInputType(for: entry),
                                        equipment: entry.equipment,
                                        size: 24
                                    )
                                    .padding(DS.Spacing.xs)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                        Text(entry.exerciseName)
                                            .font(DS.Typography.tileSubtitle.weight(.semibold))
                                            .lineLimit(2)

                                        let profile = TemplateExerciseProfile(
                                            inputTypeRaw: resolvedInputType(for: entry),
                                            cardioSecondaryUnitRaw: resolvedCardioSecondaryUnitRaw(for: entry)
                                        )

                                        HStack(spacing: DS.Spacing.xs) {
                                            if profile.showsStrengthDefaultsEditor {
                                                Text("\(entry.defaultSets)\u{00d7}\(entry.defaultReps)")
                                                if resolvedInputType(for: entry) != ExerciseInputType.roundsBased.rawValue,
                                                   let kg = entry.defaultWeightKg, kg > 0 {
                                                    Text("\u{00b7} \(kg, specifier: "%.1f")kg")
                                                }
                                            } else {
                                                Text(profile.primarySummaryLabel)
                                                if let secondary = profile.secondarySummaryLabel {
                                                    Text("\u{00b7} \(secondary)")
                                                }
                                            }
                                        }
                                        .font(DS.Typography.metricLabel)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                if isReordering && reorderedEntries.count > 1 {
                                    HStack(spacing: DS.Spacing.sm) {
                                        Button {
                                            guard index > 0 else { return }
                                            reorderedEntries.swapAt(index, index - 1)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                                .font(.caption2)
                                                .frame(maxWidth: .infinity, minHeight: 44)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(index == 0)
                                        .accessibilityLabel("Move Up")

                                        Button {
                                            guard index + 1 < reorderedEntries.count else { return }
                                            reorderedEntries.swapAt(index, index + 1)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                                .font(.caption2)
                                                .frame(maxWidth: .infinity, minHeight: 44)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(index == reorderedEntries.count - 1)
                                        .accessibilityLabel("Move Down")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(
                            String(
                                format: String(localized: "%@ exercises"),
                                locale: Locale.current,
                                reorderedEntries.count.formattedWithSeparator
                            )
                        )
                    }
                }
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStrengthList)
                .scrollContentBackground(.hidden)
                .onChange(of: errorMessage) { _, newValue in
                    if newValue != nil {
                        proxy.scrollTo("start-error", anchor: .top)
                    }
                }
            }

            Button {
                startStrengthWorkout()
            } label: {
                HStack {
                    if isStarting {
                        ProgressView()
                            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStarting)
                            .tint(.black)
                    } else {
                        Image(systemName: errorMessage == nil ? "play.fill" : "arrow.clockwise")
                    }
                    Text(errorMessage == nil ? String(localized: "Start") : String(localized: "Retry"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentColor)
            .disabled(isStarting)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStartButton)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xs)
        }
    }

    private func startStrengthWorkout() {
        guard !isStarting else { return }
        isStarting = true
        errorMessage = nil

        let reorderedSnapshot = WorkoutSessionTemplate(
            name: snapshot.name,
            entries: reorderedEntries.map {
                resolvedWatchEntry($0, exercise: connectivity.exerciseInfo(for: $0.exerciseDefinitionID))
            },
            procedureSetsByExerciseID: snapshot.procedureSetsByExerciseID
        )

        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startQuickWorkout(with: reorderedSnapshot)
                WKInterfaceDevice.current().play(.success)
                isStarting = false
            } catch {
                isStarting = false
                presentStartError(error)
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func startErrorNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DS.Color.negative)
                .accessibilityHidden(true)
            Text(message)
                .font(DS.Typography.metricLabel)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.negative.opacity(DS.Opacity.border), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("watch-workout-preview-start-error")
    }

    private func presentStartError(_ error: Error) {
        if let startupError = error as? WorkoutStartupError,
           let description = startupError.errorDescription,
           !description.isEmpty {
            errorMessage = description
            return
        }
        errorMessage = String(localized: "Could not start workout. Please try again.")
    }
}
