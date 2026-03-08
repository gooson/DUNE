import UIKit

extension SpatialTrainingSummary.MuscleLoad {
    var recoveryLabel: String {
        guard hasRecentLoad else { return String(localized: "No recent load") }
        let percent = Int((recoveryPercent * 100).rounded())
        return String(localized: "\(percent.formatted())% recovered")
    }

    var loadLabel: String {
        String(localized: "\(weeklyLoadUnits.formatted()) u")
    }

    var fatigueLabel: String {
        fatigueLevel.displayName
    }
}

enum VisionSpatialPalette {
    static func orbColor(heatLevel: Double, alpha: CGFloat = 1.0) -> UIColor {
        let level = heatLevel.clamped(to: 0...1)
        return UIColor(
            hue: 0.62 - (0.56 * level),
            saturation: 0.48 + (0.32 * level),
            brightness: 0.92,
            alpha: alpha
        )
    }

    static func muscleColor(for muscle: MuscleGroup, alpha: CGFloat = 1.0) -> UIColor {
        let hue: CGFloat
        switch muscle {
        case .chest: hue = 0.02
        case .back: hue = 0.58
        case .shoulders: hue = 0.11
        case .biceps: hue = 0.08
        case .triceps: hue = 0.14
        case .quadriceps: hue = 0.30
        case .hamstrings: hue = 0.35
        case .glutes: hue = 0.42
        case .calves: hue = 0.50
        case .core: hue = 0.18
        case .forearms: hue = 0.66
        case .traps: hue = 0.74
        case .lats: hue = 0.82
        }

        return UIColor(hue: hue, saturation: 0.56, brightness: 0.94, alpha: alpha)
    }

    static func fatigueColor(
        normalizedFatigue: Double,
        isSelected: Bool
    ) -> UIColor {
        let level = normalizedFatigue.clamped(to: 0...1)
        let base = UIColor(
            hue: 0.30 - (0.30 * level),
            saturation: 0.42 + (0.34 * level),
            brightness: 0.72 + (0.18 * (1 - level)),
            alpha: 1
        )

        guard isSelected else { return base }
        return base.blended(with: .white, ratio: 0.22)
    }

    static func blockColor(
        for muscle: MuscleGroup,
        selected: Bool
    ) -> UIColor {
        let base = muscleColor(for: muscle, alpha: selected ? 1.0 : 0.86)
        guard selected else { return base }
        return base.blended(with: .white, ratio: 0.16)
    }
}

