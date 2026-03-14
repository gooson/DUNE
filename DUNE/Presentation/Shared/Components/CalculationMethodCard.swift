import SwiftUI

/// Unified calculation method explainer card for score detail views.
/// Shows formula icon + title + bullet-point explanations.
struct CalculationMethodCard: View {
    let icon: String
    let title: LocalizedStringKey
    let bullets: [LocalizedStringKey]

    init(
        icon: String,
        title: LocalizedStringKey,
        bullets: [LocalizedStringKey]
    ) {
        self.icon = icon
        self.title = title
        self.bullets = bullets
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }

                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    bulletRow(bullet)
                }
            }
        }
    }

    private func bulletRow(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Circle()
                .fill(.tertiary)
                .frame(width: 4, height: 4)
                .padding(.top, 6)

            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
