import Foundation

/// Training readiness score combining HRV, RHR, sleep, and muscle fatigue.
struct TrainingReadiness: Sendable, Hashable {
    let score: Int
    let status: Status
    let components: Components
    let isCalibrating: Bool

    enum Status: String, Sendable, CaseIterable {
        case ready
        case moderate
        case light
        case rest
    }

    struct Components: Sendable, Hashable {
        let hrvScore: Int
        let rhrScore: Int
        let sleepScore: Int
        let fatigueScore: Int
        let trendBonus: Int
    }

    /// Data-driven narrative for hero card display.
    var narrativeMessage: String {
        let weakest = findWeakestComponent()
        switch status {
        case .ready:
            return String(localized: "Full intensity training recommended")
        case .moderate:
            if let weakest {
                return String(localized: "Normal training — \(weakest) needs attention")
            }
            return String(localized: "Normal training is fine")
        case .light:
            if let weakest {
                return String(localized: "Reduce volume — \(weakest) is low")
            }
            return String(localized: "Reduce volume. Active recovery")
        case .rest:
            return String(localized: "Rest or very light movement only")
        }
    }

    /// Returns the name of the weakest component, if significantly lower.
    private func findWeakestComponent() -> String? {
        let pairs: [(String, Int)] = [
            (String(localized: "HRV"), components.hrvScore),
            (String(localized: "sleep"), components.sleepScore),
            (String(localized: "recovery"), components.fatigueScore)
        ]
        guard let min = pairs.min(by: { $0.1 < $1.1 }) else { return nil }
        // Only call out if notably weaker than average of others
        let others = pairs.filter { $0.0 != min.0 }
        let othersAvg = others.isEmpty ? 0 : others.map(\.1).reduce(0, +) / others.count
        if min.1 < othersAvg - 15 { return min.0 }
        return nil
    }

    init(score: Int, components: Components, isCalibrating: Bool = false) {
        self.score = max(0, min(100, score))
        self.components = components
        self.isCalibrating = isCalibrating

        switch self.score {
        case 80...100: self.status = .ready
        case 60...79: self.status = .moderate
        case 40...59: self.status = .light
        default: self.status = .rest
        }
    }
}
