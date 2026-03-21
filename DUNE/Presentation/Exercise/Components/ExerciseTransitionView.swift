import SwiftUI

/// Full-screen interstitial shown between exercises in a template workout.
/// Displays the upcoming exercise's info and auto-advances after a countdown.
struct ExerciseTransitionView: View {
    let exercise: ExerciseDefinition
    let entry: TemplateEntry
    let exerciseNumber: Int
    let totalExercises: Int
    let onStart: () -> Void

    @State private var countdown = 5
    @State private var didStart = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Progress label
            Text("EXERCISE \(exerciseNumber) OF \(totalExercises)")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.Color.textSecondary)
                .tracking(2)

            // Exercise icon
            exercise.equipment.svgIcon(size: 48)
                .foregroundStyle(exercise.resolvedActivityType.color)
                .frame(width: 80, height: 80)
                .background(
                    exercise.resolvedActivityType.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DS.Radius.lg)
                )

            // Exercise name + category
            VStack(spacing: DS.Spacing.xs) {
                Text(exercise.localizedName)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(exercise.categoryDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            // Template defaults
            templateDefaultsRow

            Spacer()

            // Start button with countdown
            Button {
                guard !didStart else { return }
                didStart = true
                onStart()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "play.fill")
                    if countdown > 0 {
                        Text("Start (\(countdown))")
                            .contentTransition(.numericText())
                    } else {
                        Text("Start")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.activity)
            .accessibilityIdentifier("template-workout-transition-start")
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .accessibilityIdentifier("template-workout-transition-screen")
        .background { DetailWaveBackground() }
        .task {
            for tick in stride(from: 4, through: 0, by: -1) {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch { return }
                guard !Task.isCancelled, !didStart else { return }
                withAnimation { countdown = tick }
            }
            guard !Task.isCancelled, !didStart else { return }
            didStart = true
            onStart()
        }
    }

    // MARK: - Template Defaults

    private var templateDefaultsRow: some View {
        let profile = TemplateExerciseProfile(exercise: exercise)

        return HStack(spacing: DS.Spacing.lg) {
            if profile.showsStrengthDefaultsEditor {
                Label("\(entry.defaultSets) sets", systemImage: "list.number")
                Label("\(entry.defaultReps) reps", systemImage: "repeat")
                if let weight = entry.defaultWeightKg, weight > 0 {
                    Label("\(Int(weight)) kg", systemImage: "scalemass")
                }
            } else {
                Label(profile.primarySummaryLabel, systemImage: exercise.resolvedActivityType.iconName)
                if let secondary = profile.secondarySummaryLabel {
                    Label(secondary, systemImage: "ruler")
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(DS.Color.textSecondary)
    }
}
