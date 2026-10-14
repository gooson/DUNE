import SwiftUI

/// Horizontal bar showing the active HealthKit or estimated heart rate zone.
/// Active zone is highlighted; others are dimmed.
struct HRZoneBar: View {
    let activeIndex: Int?
    let zoneCount: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...max(1, zoneCount), id: \.self) { index in
                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .fill(Self.color(for: index, count: zoneCount).opacity(index == activeIndex ? 1.0 : DS.Opacity.strong))
                    .frame(height: index == activeIndex ? 6 : 4)
                    .animation(DS.Animation.standard, value: activeIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart Rate Zones")
        .accessibilityValue(String(zoneCount))
        .accessibilityIdentifier("watch-live-heart-rate-zones")
    }

    static func color(for index: Int, count: Int) -> Color {
        let scaled = count > 1
            ? Int((Double(index - 1) / Double(count - 1) * 4).rounded()) + 1
            : 1
        return HeartRateZone.Zone(rawValue: min(max(scaled, 1), 5))?.color ?? DS.Color.zone5
    }
}
