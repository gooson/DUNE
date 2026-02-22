import SwiftUI

/// 2-column grid of strength personal records.
struct PersonalRecordsSection: View {
    let records: [StrengthPersonalRecord]

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(records.prefix(8)) { record in
                    prCard(record)
                }
            }
        }
    }

    private func prCard(_ record: StrengthPersonalRecord) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Exercise name
                Text(record.exerciseName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Weight
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(String(format: "%.0f", record.maxWeight))
                        .font(DS.Typography.cardScore)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    if record.isRecent {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DS.Color.activity, in: Capsule())
                    }
                }

                // Date
                Text(record.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "trophy")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Log sets with weight to track PRs.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }
}
