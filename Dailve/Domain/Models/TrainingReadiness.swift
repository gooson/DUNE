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
