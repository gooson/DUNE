import SwiftUI

/// Fullscreen exercise card for the carousel home.
/// Displays centered equipment icon + exercise name + recent stats.
struct ExerciseCardView: View {
    let exercise: WatchExerciseInfo
    let sectionLabel: String
    let sectionColor: Color

    private let resolvedIcon: EquipmentIcon.Resolved
    private let subtitle: String?
    private let daysAgo: String?

    init(exercise: WatchExerciseInfo, sectionLabel: String, sectionColor: Color) {
        self.exercise = exercise
        self.sectionLabel = sectionLabel
        self.sectionColor = sectionColor
        self.resolvedIcon = EquipmentIcon.resolve(for: exercise.equipment)

        // Pre-compute subtitle from latest set (Correction #102 — no body-called service)
        let latest = RecentExerciseTracker.latestSet(exerciseID: exercise.id)
        let reps = latest?.reps ?? exercise.defaultReps ?? 10

        var parts: [String] = []
        if let w = latest?.weight, w > 0, w <= 500 {
            parts.append("\(w.formattedWeight)kg")
        }
        parts.append("\(reps) reps")
        parts.append("\(exercise.defaultSets) sets")
        self.subtitle = parts.joined(separator: " · ")

        // Days ago
        if let lastUsedDate = RecentExerciseTracker.lastUsed(exerciseID: exercise.id) {
            let days = Calendar.current.dateComponents([.day], from: lastUsedDate, to: Date()).day ?? 0
            if days == 0 {
                self.daysAgo = "Today"
            } else if days == 1 {
                self.daysAgo = "Yesterday"
            } else if days <= 30 {
                self.daysAgo = "\(days)d ago"
            } else {
                self.daysAgo = nil
            }
        } else {
            self.daysAgo = nil
        }
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

            // Subtitle: weight · reps · sets
            if let subtitle {
                Text(subtitle)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

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
