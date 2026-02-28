import SwiftUI

extension FatigueLevel {

    var displayName: String {
        switch self {
        case .noData:           "데이터 없음"
        case .fullyRecovered:   "완전 회복"
        case .wellRested:       "충분한 휴식"
        case .lightFatigue:     "가벼운 피로"
        case .mildFatigue:      "경미한 피로"
        case .moderateFatigue:  "중간 피로"
        case .notableFatigue:   "상당한 피로"
        case .highFatigue:      "높은 피로"
        case .veryHighFatigue:  "매우 높은 피로"
        case .extremeFatigue:   "극심한 피로"
        case .overtrained:      "과훈련"
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

    /// Stroke color for muscle map outline.
    func strokeColor(for colorScheme: ColorScheme) -> Color {
        if self == .noData { return ColorCache.noDataStrokeColor }
        return color(for: colorScheme).opacity(0.6)
    }

    private enum ColorCache {
        static let noDataColor = Color.secondary.opacity(0.2)
        static let noDataStrokeColor = Color.secondary.opacity(0.15)

        // Index 0 = noData (unused via early return), 1..10 = fullyRecovered..overtrained
        static let dark: [Color] = buildColors(isDark: true)
        static let light: [Color] = buildColors(isDark: false)

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
