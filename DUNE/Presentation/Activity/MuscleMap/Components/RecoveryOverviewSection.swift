import SwiftUI

/// Recovery overview section showing muscle recovery status summary.
struct RecoveryOverviewSection: View {
    let fatigueStates: [MuscleFatigueState]
    let recoveredCount: Int
    let overworkedMuscles: [MuscleGroup]
    let nextRecovery: (muscle: MuscleGroup, date: Date)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Recovery progress
            recoveryProgress

            // Overworked warning
            if !overworkedMuscles.isEmpty {
                overworkedWarning
            }

            // Next recovery
            if let next = nextRecovery {
                nextRecoveryRow(muscle: next.muscle, date: next.date)
            }
        }
    }

    // MARK: - Recovery Progress

    private var recoveryProgress: some View {
        let total = fatigueStates.count
        let fraction = total > 0 ? Double(recoveredCount) / Double(total) : 0

        return HStack(spacing: DS.Spacing.md) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(DS.Color.activity, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(recoveredCount)")
                    .font(.title3.weight(.bold).monospacedDigit())
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if total > 0 {
                    Text("\(recoveredCount)/\(total) muscles ready")
                        .font(.subheadline.weight(.medium))
                    Text(recoveredCount == total ? "All muscle groups are recovered" : "\(total - recoveredCount) still recovering")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                } else {
                    Text("Start training to track recovery")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Overworked Warning

    private var overworkedWarning: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Overworked")
                    .font(.subheadline.weight(.medium))
            }

            HStack(spacing: DS.Spacing.xs) {
                ForEach(overworkedMuscles, id: \.self) { muscle in
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: muscle.iconName)
                            .font(.caption2)
                        Text(muscle.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Next Recovery

    private func nextRecoveryRow(muscle: MuscleGroup, date: Date) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.subheadline)
                .foregroundStyle(DS.Color.activity)

            Text("Next ready:")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            Text(muscle.displayName)
                .font(.caption.weight(.medium))

            Spacer()

            Text(timeUntil(date))
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(DS.Color.activity)
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func timeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "Ready" }
        let hours = Int(interval / 3600)
        if hours < 1 { return "< 1h" }
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        let remainingHours = hours % 24
        return remainingHours > 0 ? "\(days)d \(remainingHours)h" : "\(days)d"
    }
}
