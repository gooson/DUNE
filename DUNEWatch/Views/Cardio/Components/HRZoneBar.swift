import SwiftUI

/// Horizontal 5-segment bar showing current heart rate zone.
/// Active zone is highlighted; others are dimmed.
struct HRZoneBar: View {
    let currentZone: HeartRateZone.Zone?
    let fraction: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HeartRateZone.Zone.allCases, id: \.rawValue) { zone in
                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .fill(zone.color.opacity(zone == currentZone ? 1.0 : DS.Opacity.strong))
                    .frame(height: zone == currentZone ? 6 : 4)
                    .animation(DS.Animation.standard, value: currentZone)
            }
        }
    }
}
