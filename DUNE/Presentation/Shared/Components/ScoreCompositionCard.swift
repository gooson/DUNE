import SwiftUI

/// Shared component weight breakdown card for score detail views.
/// Shows how each sub-component contributes to the final score.
struct ScoreCompositionCard: View {
    let title: LocalizedStringKey
    let components: [Component]

    @Environment(\.appTheme) private var theme

    struct Component: Identifiable {
        var id: String { label }
        let label: String
        let weight: String
        let score: Int?
        let color: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ForEach(components) { component in
                weightRow(component)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func weightRow(_ component: Component) -> some View {
        HStack {
            Text(component.label)
                .font(.subheadline)

            Spacer()

            Text(component.weight)
                .font(.caption)
                .foregroundStyle(.tertiary)

            GeometryReader { geo in
                let resolved = max(0, min(component.score ?? 0, 100))
                let fraction = CGFloat(resolved) / 100.0

                Capsule()
                    .fill(component.color.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(component.color)
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(width: 60, height: 6)
            .clipShape(Capsule())

            Text(component.score.map { "\($0)" } ?? "--")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(component.score != nil ? theme.sandColor : Color.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
