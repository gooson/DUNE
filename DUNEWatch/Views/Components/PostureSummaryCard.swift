import SwiftUI

/// Compact posture monitoring summary card for Watch carousel.
/// Shows sedentary time and latest gait score.
struct PostureSummaryCard: View {
    let sedentaryMinutes: Int
    let averageGaitScore: Int?
    let thresholdMinutes: Int

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("POSTURE")
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Spacer()

            // Sedentary time
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: sedentaryIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(sedentaryColor)

                Text(PostureFormatting.formatMinutes(sedentaryMinutes))
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(sedentaryColor)

                Text("Sitting today")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            // Gait score (if available)
            if let score = averageGaitScore {
                let color = gaitColor(for: score)
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(color)
                    Text("Gait \(score)")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(color)
                }
                .padding(.top, DS.Spacing.xxs)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Computed

    private var sedentaryIcon: String {
        if sedentaryMinutes >= thresholdMinutes {
            return "figure.stand"
        }
        return "figure.seated.seatbelt"
    }

    private var sedentaryColor: Color {
        if sedentaryMinutes >= thresholdMinutes * 2 {
            return DS.Color.negative
        }
        if sedentaryMinutes >= thresholdMinutes {
            return DS.Color.caution
        }
        return DS.Color.positive
    }

    private func gaitColor(for score: Int) -> Color {
        if score >= 70 { return DS.Color.positive }
        if score >= 40 { return DS.Color.caution }
        return DS.Color.negative
    }
}
