import SwiftUI

extension FatigueLevel {

    var displayName: String {
        switch self {
        case .noData:           String(localized: "No Data")
        case .fullyRecovered:   String(localized: "Fully Recovered")
        case .wellRested:       String(localized: "Well Rested")
        case .lightFatigue:     String(localized: "Light Fatigue")
        case .mildFatigue:      String(localized: "Mild Fatigue")
        case .moderateFatigue:  String(localized: "Moderate Fatigue")
        case .notableFatigue:   String(localized: "Notable Fatigue")
        case .highFatigue:      String(localized: "High Fatigue")
        case .veryHighFatigue:  String(localized: "Very High Fatigue")
        case .extremeFatigue:   String(localized: "Extreme Fatigue")
        case .overtrained:      String(localized: "Overtrained")
        }
    }

    var shortLabel: String {
        switch self {
        case .noData:   "—"
        default:        "L\(rawValue)"
        }
    }

    /// Desert-toned HSB color from sage (L1) to terracotta (L10).
    /// Colors are cached as static arrays to avoid creating new Color instances per render cycle (Correction #83).
    func color(for colorScheme: ColorScheme) -> Color {
        if self == .noData { return ColorCache.noDataColor }
        let cache = colorScheme == .dark ? ColorCache.dark : ColorCache.light
        return cache[Int(rawValue)]
    }

    /// Stroke color for muscle map outline (cached — avoids per-render .opacity allocation).
    func strokeColor(for colorScheme: ColorScheme) -> Color {
        if self == .noData { return ColorCache.noDataStrokeColor }
        let cache = colorScheme == .dark ? ColorCache.darkStroke : ColorCache.lightStroke
        return cache[Int(rawValue)]
    }

    private enum ColorCache {
        static let noDataColor = Color(DS.Color.textTertiary).opacity(DS.Opacity.overlay)
        static let noDataStrokeColor = Color(DS.Color.textTertiary).opacity(DS.Opacity.border)

        // Index 0 = noData (unused via early return), 1..10 = fullyRecovered..overtrained
        static let dark: [Color] = buildColors(isDark: true)
        static let light: [Color] = buildColors(isDark: false)
        // Stroke variants cached per Correction #83
        static let darkStroke: [Color] = buildColors(isDark: true).map { $0.opacity(0.6) }
        static let lightStroke: [Color] = buildColors(isDark: false).map { $0.opacity(0.6) }

        // Desert-toned palette: sage/olive → sand/amber → terracotta/burnt sienna
        private static func buildColors(isDark: Bool) -> [Color] {
            let specs: [(hue: Double, sat: Double, darkB: Double, lightB: Double)] = [
                (0, 0, 0, 0),              // 0: noData placeholder
                (0.28, 0.30, 0.75, 0.55),  // 1: fullyRecovered — desert sage
                (0.25, 0.32, 0.78, 0.58),  // 2: wellRested — warm olive
                (0.20, 0.35, 0.80, 0.62),  // 3: lightFatigue — sand olive
                (0.14, 0.38, 0.82, 0.65),  // 4: mildFatigue — warm sand
                (0.10, 0.42, 0.82, 0.68),  // 5: moderateFatigue — desert amber
                (0.07, 0.45, 0.80, 0.65),  // 6: notableFatigue — copper sand
                (0.05, 0.48, 0.75, 0.60),  // 7: highFatigue — terracotta
                (0.03, 0.50, 0.70, 0.55),  // 8: veryHighFatigue — burnt sienna
                (0.01, 0.52, 0.65, 0.50),  // 9: extremeFatigue — deep clay
                (0.00, 0.55, 0.58, 0.45),  // 10: overtrained — dark terracotta
            ]
            return specs.map { spec in
                Color(hue: spec.hue, saturation: spec.sat, brightness: isDark ? spec.darkB : spec.lightB)
            }
        }
    }
}
