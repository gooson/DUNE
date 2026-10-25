import SwiftUI

/// A noninteractive history summary. Larger text uses dated rows instead of shrinking labels.
struct WeeklyHeroTrendView: View {
    let points: [WeeklyHeroTrendPoint]
    let title: LocalizedStringKey
    let upperBound: Int
    let tint: Color
    let accessibilityIdentifier: String

    private enum Labels {
        static let noRecord = String(localized: "No record")
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var ink: Color { theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor }
    private var muted: Color { theme == .desertWarm ? DesertPalette.muted : ink.opacity(0.74) }
    private var hasHistory: Bool { points.lazy.compactMap(\.value).prefix(2).count == 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.caption.weight(.semibold))
                    Spacer(minLength: DS.Spacing.sm)
                    period
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title).font(.caption.weight(.semibold))
                    period
                }
            }

            if hasHistory {
                if dynamicTypeSize >= .xxLarge {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                            HStack {
                                Text(point.date, format: .dateTime.month(.abbreviated).day())
                                Spacer(minLength: DS.Spacing.md)
                                valueText(point)
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("\(accessibilityIdentifier)-day-\(index)")
                        }
                    }
                } else {
                    HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                            VStack(spacing: DS.Spacing.sm) {
                                valueText(point)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(ink)
                                ZStack(alignment: .bottom) {
                                    Rectangle().fill(.clear)
                                    if let value = point.value {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(tint.opacity(point.id == points.last?.id ? 1 : 0.55))
                                            .frame(width: 14, height: barHeight(value))
                                    }
                                }
                                .frame(height: 48)
                                .accessibilityHidden(true)
                                Text(point.date, format: .dateTime.day())
                                    .font(.caption2)
                                    .foregroundStyle(muted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(point.date, format: .dateTime.month(.abbreviated).day()))
                            .accessibilityValue(point.value.map { $0.formattedWithSeparator } ?? Labels.noRecord)
                            .accessibilityIdentifier("\(accessibilityIdentifier)-day-\(index)")
                        }
                    }
                }
            } else {
                Text("Not enough data to show trend.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
        }
        .foregroundStyle(ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var period: some View {
        if let first = points.first, let last = points.last {
            Text(verbatim: "\(first.date.formatted(.dateTime.month(.abbreviated).day()))–\(last.date.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption2)
                .foregroundStyle(muted)
        }
    }

    private func valueText(_ point: WeeklyHeroTrendPoint) -> Text {
        Text(verbatim: point.value.map { $0.formattedWithSeparator } ?? "—")
            .monospacedDigit()
    }

    private func barHeight(_ value: Int) -> CGFloat {
        let fraction = Double(Swift.max(0, value)) / Double(Swift.max(1, upperBound))
        return 48 * Swift.min(1, fraction)
    }
}

#Preview("Recorded values and a missing day") {
    WeeklyHeroTrendView(
        points: WeeklyHeroTrendPoint.readinessHistory(samples: [], current: nil),
        title: "Recorded Readiness",
        upperBound: 100,
        tint: .accentColor,
        accessibilityIdentifier: "preview-trend"
    )
    .padding()
}
