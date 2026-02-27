import SwiftUI

/// Fullscreen exercise card for the carousel home.
/// Displays centered equipment icon + exercise name + recent stats.
/// All display data is pre-computed by the caller (P2 #5 — no UserDefaults in init).
struct ExerciseCardView: View {
    let exercise: WatchExerciseInfo
    let sectionLabel: String
    let sectionColor: Color
    let daysAgo: String?

    private let resolvedIcon: EquipmentIcon.Resolved
    private let subtitle: String

    init(exercise: WatchExerciseInfo, sectionLabel: String, sectionColor: Color, daysAgo: String?) {
        self.exercise = exercise
        self.sectionLabel = sectionLabel
        self.sectionColor = sectionColor
        self.daysAgo = daysAgo
        self.resolvedIcon = EquipmentIcon.resolve(for: exercise.equipment)

        // Build subtitle from exercise defaults (no UserDefaults access)
        self.subtitle = exerciseSubtitle(
            sets: exercise.defaultSets,
            reps: exercise.defaultReps ?? 10,
            weight: exercise.defaultWeightKg
        )
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Section badge
            Text(sectionLabel)
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(sectionColor)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

            // Equipment icon (large, centered)
            iconView
                .frame(width: 60, height: 60)

            // Exercise name
            Text(exercise.name)
                .font(.system(.title3, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

            // Subtitle: sets · reps · weight
            Text(subtitle)
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            // Days ago
            if let daysAgo {
                Text(daysAgo)
                    .font(DS.Typography.tinyLabel)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconView: some View {
        switch resolvedIcon {
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(DS.Color.warmGlow)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 34))
                .foregroundStyle(DS.Color.warmGlow)
        }
    }
}
