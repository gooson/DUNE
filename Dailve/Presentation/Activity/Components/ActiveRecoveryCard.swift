import SwiftUI

/// Horizontal scroll of active recovery suggestions for rest days.
struct ActiveRecoveryCard: View {
    let suggestions: [ActiveRecoverySuggestion]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(suggestions) { item in
                    suggestionChip(item)
                }
            }
        }
    }

    private func suggestionChip(_ item: ActiveRecoverySuggestion) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: item.iconName)
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
                .frame(width: 36, height: 36)
                .background(DS.Color.activity.opacity(0.1), in: Circle())

            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text(item.duration)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 90)
        .padding(.vertical, DS.Spacing.sm)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

#Preview {
    ActiveRecoveryCard(suggestions: ActiveRecoverySuggestion.defaults)
        .padding()
}
