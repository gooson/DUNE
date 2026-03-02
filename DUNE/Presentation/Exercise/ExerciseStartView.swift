import SwiftUI

/// Pre-workout confirmation sheet for iPhone single exercise flow.
/// Presented as a non-dismissable bottom sheet (.large detent, no drag indicator).
/// Start button pushes into a full-screen NavigationStack for WorkoutSessionView.
struct ExerciseStartView: View {
    let exercise: ExerciseDefinition
    @Environment(\.dismiss) private var dismiss
    @State private var showSession = false

    /// Whether this exercise should use the cardio live tracking flow.
    private var isCardioLiveTracking: Bool {
        exercise.inputType == .durationDistance
            && exercise.resolvedActivityType.isDistanceBased
    }

    var body: some View {
        if isCardioLiveTracking {
            CardioStartSheet(exercise: exercise)
        } else {
            strengthFlow
        }
    }

    private var strengthFlow: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        exerciseInfoCard
                        muscleSection
                        detailRow
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, 100)
                }

                startButton
            }
            .background { SheetWaveBackground() }
            .navigationTitle(exercise.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showSession) {
                WorkoutSessionView(exercise: exercise)
            }
        }
    }

    // MARK: - Exercise Info Card

    private var exerciseInfoCard: some View {
        HStack(spacing: DS.Spacing.md) {
            exercise.equipment.svgIcon(size: 36)
                .foregroundStyle(exercise.resolvedActivityType.color)
                .frame(width: 60, height: 60)
                .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.localizedName)
                    .font(.title2.weight(.bold))

                Text(exercise.categoryDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Muscles

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !exercise.primaryMuscles.isEmpty {
                Text("Primary Muscles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)

                FlowLayout(spacing: DS.Spacing.xs) {
                    ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Color.activity.opacity(0.15), in: Capsule())
                            .foregroundStyle(DS.Color.activity)
                    }
                }
            }

            if !exercise.secondaryMuscles.isEmpty {
                Text("Secondary Muscles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.top, DS.Spacing.xs)

                FlowLayout(spacing: DS.Spacing.xs) {
                    ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Detail Row

    private var detailRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            Label {
                Text(exercise.equipment.displayName)
            } icon: {
                exercise.equipment.svgIcon(size: 14)
            }
            Label("\(WorkoutDefaults.setCount.formattedWithSeparator) sets", systemImage: "list.number")
        }
        .font(.subheadline)
        .foregroundStyle(DS.Color.textSecondary)
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showSession = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.activity)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .background(.ultraThinMaterial)
    }
}
