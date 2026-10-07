import SwiftUI

/// Shared component weight breakdown card for score detail views.
/// Shows how each sub-component contributes to the final score.
struct ScoreCompositionCard: View {
    let title: LocalizedStringKey
    let components: [Component]

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("score-composition-card")
    }

    private func weightRow(_ component: Component) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    componentLabel(component)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DS.Spacing.sm) {
                        componentWeight(component)
                        componentBar(component)
                        componentScore(component)
                            .fixedSize()
                    }
                }
            } else {
                HStack {
                    componentLabel(component)

                    Spacer()

                    componentWeight(component)
                    componentBar(component)
                        .frame(width: 60)
                    componentScore(component)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func componentLabel(_ component: Component) -> some View {
        Text(component.label)
            .font(.subheadline)
    }

    private func componentWeight(_ component: Component) -> some View {
        Text(component.weight)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private func componentBar(_ component: Component) -> some View {
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
        .frame(height: 6)
        .clipShape(Capsule())
    }

    private func componentScore(_ component: Component) -> some View {
        Text(component.score.map { "\($0)" } ?? "--")
            .font(.caption)
            .fontWeight(.medium)
            .monospacedDigit()
            .foregroundStyle(component.score != nil ? theme.sandColor : Color.secondary)
    }
}
