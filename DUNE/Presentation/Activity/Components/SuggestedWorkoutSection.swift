import SwiftUI

/// Standalone suggested workout section, extracted from MuscleRecoveryMapView.
struct SuggestedWorkoutSection: View {
    let suggestion: WorkoutSuggestion?
    let recommendationContext: WorkoutRecommendationContext
    let availableEquipment: [Equipment]
    let onStartExercise: (ExerciseDefinition) -> Void
    let onContextChanged: (WorkoutRecommendationContext) -> Void
    let isEquipmentAvailable: (Equipment) -> Bool
    let onSetEquipmentAvailability: (Equipment, Bool) -> Void
    let isExerciseExcluded: (String) -> Bool
    let onSetExerciseExcluded: (Bool, String) -> Void

    @State private var showingEquipmentSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            recommendationControlsCard

            if let suggestion {
                if suggestion.isRestDay {
                    restDayContent(suggestion: suggestion)
                } else {
                    workoutContent(suggestion: suggestion)
                }
            } else {
                noSuggestionContent
            }
        }
        .sheet(isPresented: $showingEquipmentSheet) {
            RecommendationEquipmentSheet(
                context: recommendationContext,
                isEquipmentAvailable: isEquipmentAvailable,
                onSetEquipmentAvailability: onSetEquipmentAvailability
            )
        }
    }

    // MARK: - Controls

    private var recommendationControlsCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Picker(
                    "Workout Context",
                    selection: Binding(
                        get: { recommendationContext },
                        set: { onContextChanged($0) }
                    )
                ) {
                    Text("Gym")
                        .tag(WorkoutRecommendationContext.gym)
                    Text("Home")
                        .tag(WorkoutRecommendationContext.home)
                }
                .pickerStyle(.segmented)

                Button {
                    showingEquipmentSheet = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity)

                        Text("Equipment")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.Color.textSecondary)

                        Spacer(minLength: DS.Spacing.xs)

                        Text("\(availableEquipment.count.formattedWithSeparator) selected")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noSuggestionContent: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("No matching workout suggestions")
                    .font(.subheadline.weight(.semibold))

                Text("Update your equipment or remove not-interested exercises.")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Workout

    private func workoutContent(suggestion: WorkoutSuggestion) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if !suggestion.focusMuscles.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(suggestion.focusMuscles, id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(DS.Color.activity.opacity(0.12), in: Capsule())
                                .foregroundStyle(DS.Color.activity)
                        }
                    }
                }

                ForEach(suggestion.exercises) { exercise in
                    let excluded = isExerciseExcluded(exercise.id)
                    SuggestedExerciseRow(
                        exercise: exercise,
                        isExcluded: excluded,
                        onStart: { onStartExercise(exercise.definition) },
                        onToggleInterest: {
                            onSetExerciseExcluded(!excluded, exercise.id)
                        },
                        onAlternativeSelected: { alt in onStartExercise(alt) }
                    )
                }
            }
        }
    }

    // MARK: - Rest Day

    private func restDayContent(suggestion: WorkoutSuggestion) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bed.double.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Recovery Day")
                        .font(.subheadline.weight(.semibold))
                }

                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                if let next = suggestion.nextReadyMuscle {
                    nextReadyLabel(muscle: next.muscle, date: next.readyDate)
                }

                if !suggestion.activeRecoverySuggestions.isEmpty {
                    ActiveRecoveryCard(suggestions: suggestion.activeRecoverySuggestions)
                }
            }
        }
    }

    private func nextReadyLabel(muscle: MuscleGroup, date: Date) -> some View {
        let hours = Swift.max(0, date.timeIntervalSince(Date()) / 3600)
        let timeText: String
        if hours < 1 {
            timeText = String(localized: "soon")
        } else if hours < 24 {
            timeText = String(localized: "in ~\(Int(hours).formattedWithSeparator)h")
        } else {
            let days = Int(hours / 24)
            timeText = String(localized: "in ~\(days.formattedWithSeparator)d")
        }

        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Text(String(localized: "\(muscle.displayName) ready \(timeText)"))
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}

private struct RecommendationEquipmentSheet: View {
    let context: WorkoutRecommendationContext
    let isEquipmentAvailable: (Equipment) -> Bool
    let onSetEquipmentAvailability: (Equipment, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch context {
        case .gym:
            return "Gym Equipment"
        case .home:
            return "Home Equipment"
        }
    }

    private var selectableEquipment: [Equipment] {
        Equipment.allCases.filter { $0 != .other }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(selectableEquipment, id: \.self) { equipment in
                        Toggle(
                            isOn: Binding(
                                get: { isEquipmentAvailable(equipment) },
                                set: { isOn in
                                    onSetEquipmentAvailability(equipment, isOn)
                                }
                            )
                        ) {
                            HStack(spacing: DS.Spacing.xs) {
                                equipment.svgIcon(size: 18)
                                    .foregroundStyle(DS.Color.activity)

                                Text(equipment.displayName)
                                    .font(.subheadline)
                            }
                        }
                    }
                } footer: {
                    Text("At least one equipment is always kept to avoid an empty recommendation.")
                }
            }
            .englishNavigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
