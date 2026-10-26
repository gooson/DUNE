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
            component("HRV", value: hrv)
            component("Sleep", value: sleep)
            component("Recovery", value: recovery)
            Divider().overlay(ink.opacity(0.15))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-hero-components")
    }

    private func component(_ title: LocalizedStringKey, value: Int?) -> some View {
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            HStack {
                Text(title).foregroundStyle(muted)
                if dynamicTypeSize >= .xxLarge { Spacer(minLength: 0) }
                if dynamicTypeSize >= .xxLarge { score(value) }
            }
            .frame(width: dynamicTypeSize >= .xxLarge ? nil : 64, alignment: .leading)
            GeometryReader { geometry in
                Capsule().fill(ink.opacity(0.12))
                    .overlay(alignment: .leading) {
                        if let value {
                            Capsule().fill(theme.accentColor.gradient)
                                .frame(width: geometry.size.width * Double(Swift.max(0, Swift.min(100, value))) / 100)
                        }
                    }
            }
            .frame(height: 7)
            .accessibilityHidden(true)
            if dynamicTypeSize < .xxLarge {
                score(value)
                    .frame(width: 68, alignment: .trailing)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func score(_ value: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            Text(verbatim: value.map { $0.formattedWithSeparator } ?? "—")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ink)
                .accessibilityLabel(value.map { $0.formattedWithSeparator } ?? Labels.noRecord)
            if value != nil {
                Text(verbatim: "/100")
                    .font(.caption2)
                    .foregroundStyle(muted)
                }
        }
        .monospacedDigit()
    }
}

#Preview {
    ReadinessHeroEvidenceView(hrv: 48, sleep: nil, recovery: 72)
        .padding()
}
