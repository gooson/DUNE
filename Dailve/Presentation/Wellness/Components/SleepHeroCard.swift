import SwiftUI

struct SleepHeroCard: View {
    let sleepScore: Int
    let totalMinutes: Double
    let efficiency: Double
    let stageBreakdown: [(stage: SleepStage.Stage, minutes: Double)]

    var body: some View {
        let totalStageMinutes = stageBreakdown.map(\.minutes).reduce(0, +)
        let visibleStages = stageBreakdown.filter { $0.minutes > 0 }

        StandardCard {
            VStack(spacing: DS.Spacing.lg) {
                // Top row: Ring + Stats
                HStack(spacing: DS.Spacing.xl) {
                    ZStack {
                        ProgressRingView(
                            progress: Double(sleepScore) / 100.0,
                            ringColor: DS.Color.sleep,
                            lineWidth: 10,
                            size: 80
                        )
                        Text("\(sleepScore)")
                            .font(DS.Typography.cardScore)
                            .foregroundStyle(DS.Color.sleep)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Text(totalMinutes.hoursMinutesFormatted)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Text("\(Int(efficiency))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("efficiency")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                // Stage breakdown bar
                if totalStageMinutes > 0 {
                    VStack(spacing: DS.Spacing.sm) {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                ForEach(visibleStages, id: \.stage.rawValue) { item in
                                    let fraction = item.minutes / totalStageMinutes
                                    // Ensure minimum 4pt width for visibility
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(item.stage.color.gradient)
                                        .frame(width: Swift.max(geo.size.width * fraction - 2, 4))
                                }
                            }
                        }
                        .frame(height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        // Compact legend
                        HStack(spacing: DS.Spacing.md) {
                            ForEach(stageBreakdown, id: \.stage.rawValue) { item in
                                HStack(spacing: DS.Spacing.xxs) {
                                    Circle()
                                        .fill(item.stage.color)
                                        .frame(width: 6, height: 6)
                                    Text("\(item.stage.label) \(Int(item.minutes))m")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
