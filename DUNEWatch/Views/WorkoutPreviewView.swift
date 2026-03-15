import SwiftUI
import WatchKit

/// Pre-workout confirmation screen.
/// Strength: shows exercise list + Start button.
/// Cardio (single durationDistance exercise): shows cardio session start choices.
struct WorkoutPreviewView: View {
    let snapshot: WorkoutSessionTemplate
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityManager.self) private var connectivity
    @Environment(\.dismiss) private var dismiss

    @State private var isStarting = false
    @State private var errorMessage: String?
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
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewScreen)
        .alert(String(localized: "Error"), isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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

        return ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: activityType.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(DS.Color.activity)
                    .padding(.top, DS.Spacing.lg)

                Text(LocalizedStringKey(activityType.typeName))
                    .font(DS.Typography.exerciseName)

                if let cardioUnit, cardioUnit.supportsMachineLevel,
                   let range = cardioUnit.machineLevelRange {
                    machineLevelPicker(range: range)
                }

                if supportsOutdoor {
                    Button {
                        startCardio(
                            activityType: activityType,
                            isOutdoor: false,
                            secondaryUnit: cardioUnit
                        )
                    } label: {
                        Label(String(localized: "Indoor"), systemImage: "building.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isStarting)
                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardioIndoorButton)
                } else {
                    Button {
                        startCardio(
                            activityType: activityType,
                            isOutdoor: false,
                            secondaryUnit: cardioUnit
                        )
                    } label: {
                        Label(String(localized: "Indoor"), systemImage: "building.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Color.activity)
                    .disabled(isStarting)
                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardioIndoorButton)
                }

                if supportsOutdoor {
                    Button {
                        startCardio(
                            activityType: activityType,
                            isOutdoor: true,
                            secondaryUnit: cardioUnit
                        )
                    } label: {
                        Label(String(localized: "Outdoor"), systemImage: "sun.max.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Color.positive)
                    .disabled(isStarting)
                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardioOutdoorButton)
                }

                if isStarting {
                    ProgressView()
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStarting)
                        .padding(.top, DS.Spacing.sm)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewCardio)
    }

    private func startCardio(
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        secondaryUnit: CardioSecondaryUnit?
    ) {
        guard !isStarting else { return }
        isStarting = true

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
        VStack(spacing: DS.Spacing.xs) {
            Text("Level")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.lg) {
                Button {
                    if selectedLevel > range.lowerBound {
                        selectedLevel -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .disabled(selectedLevel <= range.lowerBound)

                Text("\(selectedLevel)")
                    .font(DS.Typography.secondaryMetric)
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())
                    .frame(minWidth: 36)

                Button {
                    if selectedLevel < range.upperBound {
                        selectedLevel += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.activity)
                .disabled(selectedLevel >= range.upperBound)
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
        }
        .onAppear {
            levelFocused = true
        }
    }

    // MARK: - Strength Start

    private var strengthStartContent: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(Array(reorderedEntries.enumerated()), id: \.element.id) { index, entry in
                        VStack(spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.md) {
                                Text("\(index + 1)")
                                    .font(DS.Typography.metricLabel)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)

                                EquipmentIconView(equipment: entry.equipment, size: 20)
                                    .frame(width: 20, height: 20)

                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(entry.exerciseName)
                                        .font(DS.Typography.tileSubtitle)
                                        .lineLimit(1)

                                    let profile = TemplateExerciseProfile(
                                        inputTypeRaw: resolvedInputType(for: entry),
                                        cardioSecondaryUnitRaw: resolvedCardioSecondaryUnitRaw(for: entry)
                                    )

                                    HStack(spacing: DS.Spacing.xs) {
                                        if profile.showsStrengthDefaultsEditor {
                                            Text("\(entry.defaultSets)\u{00d7}\(entry.defaultReps)")
                                            if let kg = entry.defaultWeightKg, kg > 0 {
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

                            if reorderedEntries.count > 1 {
                                HStack(spacing: DS.Spacing.sm) {
                                    Button {
                                        reorderedEntries.swapAt(index, index - 1)
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, minHeight: 28)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(index == 0)

                                    Button {
                                        reorderedEntries.swapAt(index, index + 1)
                                    } label: {
                                        Image(systemName: "arrow.down")
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, minHeight: 28)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(index == reorderedEntries.count - 1)
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

            Button {
                startStrengthWorkout()
            } label: {
                HStack {
                    if isStarting {
                        ProgressView()
                            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStarting)
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(String(localized: "Start"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .disabled(isStarting)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewStartButton)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xs)
        }
    }

    private func startStrengthWorkout() {
        guard !isStarting else { return }
        isStarting = true

        let reorderedSnapshot = WorkoutSessionTemplate(
            name: snapshot.name,
            entries: reorderedEntries,
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
