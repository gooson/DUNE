import SwiftUI

/// Readiness components are normalized scores, not raw health measurements.
struct ReadinessHeroEvidenceView: View {
    let hrv: Int?
    let sleep: Int?
    let recovery: Int?

    private enum Labels {
        static let noRecord = String(localized: "No record")
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var ink: Color { theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor }
    private var muted: Color { theme == .desertWarm ? DesertPalette.muted : ink.opacity(0.74) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Divider().overlay(ink.opacity(0.15))
            Text("Component scores · out of 100")
                .font(.caption)
                .foregroundStyle(muted)
            let layout = dynamicTypeSize >= .xxLarge
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.md))
            layout {
                component("HRV", value: hrv, color: DS.Color.hrv)
                component("Sleep", value: sleep, color: DS.Color.sleep)
                component("Recovery", value: recovery, color: DS.Color.activity)
            }
            Divider().overlay(ink.opacity(0.15))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-hero-components")
    }

    private func component(_ title: LocalizedStringKey, value: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(.caption)
                .foregroundStyle(muted)
            Text(verbatim: value.map { $0.formattedWithSeparator } ?? "--")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ink)
                .accessibilityLabel(value.map { $0.formattedWithSeparator } ?? Labels.noRecord)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12))
                    if let value {
                        Capsule().fill(color)
                            .frame(width: geometry.size.width * Double(Swift.max(0, Swift.min(100, value))) / 100)
                    }
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ReadinessHeroEvidenceView(hrv: 48, sleep: nil, recovery: 72)
        .padding()
}
