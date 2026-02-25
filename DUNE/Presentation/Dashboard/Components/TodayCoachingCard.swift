import SwiftUI

struct TodayCoachingCard: View {
    let message: String

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(DS.Color.activity)
                    Text("Today's Coaching")
                        .font(.subheadline.weight(.semibold))
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
