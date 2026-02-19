import SwiftUI

/// Compact weekly training progress indicator.
/// Shows filled/empty dots for active days + navigation to TrainingVolumeDetailView.
struct WeeklyProgressBar: View {
    let activeDays: Int
    let goal: Int

    var body: some View {
        NavigationLink(value: TrainingVolumeDestination.overview) {
            HStack(spacing: DS.Spacing.sm) {
                // Dots
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<goal, id: \.self) { index in
                        Circle()
                            .fill(index < activeDays ? AnyShapeStyle(DS.Color.activity) : AnyShapeStyle(.quaternary))
                            .frame(width: 10, height: 10)
                    }
                }

                // Label
                Text("\(activeDays)/\(goal) days this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        VStack(spacing: 16) {
            WeeklyProgressBar(activeDays: 3, goal: 5)
            WeeklyProgressBar(activeDays: 0, goal: 5)
            WeeklyProgressBar(activeDays: 5, goal: 5)
        }
        .padding()
    }
}
