import SwiftUI

/// Horizontal band showing the active HealthKit or estimated heart rate zone.
/// The marker is centered in a zone; it does not imply a continuous bpm position.
struct HRZoneBar: View {
    let activeIndex: Int?
    let zoneCount: Int

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...max(1, zoneCount), id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .fill(Self.color(for: index, count: zoneCount)
                            .opacity(index == activeIndex ? 1 : DS.Opacity.strong))
                        .frame(height: 8)

                    if index == activeIndex {
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 15)
                            .shadow(color: .black.opacity(0.45), radius: 1)
                            .accessibilityIdentifier("watch-live-heart-rate-marker")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 17)
            }
        }
        .animation(isLuminanceReduced ? nil : DS.Animation.standard, value: activeIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart Rate Zones")
        .accessibilityValue(activeIndex.map { Text("Zone \($0) of \(zoneCount)") } ?? Text("No heart rate"))
        .accessibilityIdentifier("watch-live-heart-rate-zones")
    }

    static func color(for index: Int, count: Int) -> Color {
        let scaled = count > 1
            ? Int((Double(index - 1) / Double(count - 1) * 4).rounded()) + 1
            : 1
        return HeartRateZone.Zone(rawValue: min(max(scaled, 1), 5))?.color ?? DS.Color.zone5
    }
}
