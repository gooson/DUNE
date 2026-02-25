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

    /// HSB-interpolated color from deep green (L1) to deep red (L10).
    /// Colors are cached as static arrays to avoid creating new Color instances per render cycle (Correction #80).
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

        private static func buildColors(isDark: Bool) -> [Color] {
            let specs: [(hue: Double, sat: Double, darkB: Double, lightB: Double)] = [
                (0, 0, 0, 0),              // 0: noData placeholder
                (0.39, 0.70, 0.90, 0.50),  // 1: fullyRecovered
                (0.36, 0.60, 0.90, 0.60),  // 2: wellRested
                (0.31, 0.55, 0.90, 0.70),  // 3: lightFatigue
                (0.22, 0.55, 0.90, 0.75),  // 4: mildFatigue
                (0.15, 0.65, 0.90, 0.80),  // 5: moderateFatigue
                (0.11, 0.70, 0.88, 0.80),  // 6: notableFatigue
                (0.07, 0.75, 0.85, 0.78),  // 7: highFatigue
                (0.04, 0.80, 0.82, 0.72),  // 8: veryHighFatigue
                (0.01, 0.82, 0.78, 0.65),  // 9: extremeFatigue
                (0.00, 0.90, 0.70, 0.50),  // 10: overtrained
            ]
            return specs.map { spec in
                Color(hue: spec.hue, saturation: spec.sat, brightness: isDark ? spec.darkB : spec.lightB)
            }
        }
    }
}
