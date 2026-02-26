import Foundation
import Observation

/// ViewModel for the Muscle Map detail view.
/// Transforms pre-fetched fatigue states into display-ready data for volume and recovery sections.
@Observable
@MainActor
final class MuscleMapDetailViewModel {
    // MARK: - State

    var selectedMuscle: MuscleGroup?
    var mode: MuscleRecoveryMapView.MapMode = .recovery

    private(set) var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] = [:]
    private(set) var sortedMuscleVolumes: [(muscle: MuscleGroup, volume: Int)] = []
    private(set) var recoveredCount = 0
    private(set) var trainedCount = 0
    private(set) var totalWeeklySets = 0
    private(set) var overworkedMuscles: [MuscleGroup] = []
    private(set) var nextRecovery: (muscle: MuscleGroup, date: Date)?
    private(set) var balanceInfo: BalanceInfo = .noData

    var weeklySetGoal: Int {
        get { UserDefaults.standard.integer(forKey: "weeklySetGoal").clamped(to: 5...30, fallback: 15) }
        set { UserDefaults.standard.set(newValue, forKey: "weeklySetGoal") }
    }

    // MARK: - Load

    /// Synchronously transforms pre-fetched fatigue states into display properties.
    func loadData(fatigueStates: [MuscleFatigueState]) {
        // Index by muscle
        fatigueByMuscle = Dictionary(
            fatigueStates.map { ($0.muscle, $0) },
            uniquingKeysWith: { _, last in last }
        )

        // Volume: build for all muscles (0 for untrained)
        var volumes: [MuscleGroup: Int] = [:]
        for muscle in MuscleGroup.allCases {
            volumes[muscle] = fatigueByMuscle[muscle]?.weeklyVolume ?? 0
        }
        sortedMuscleVolumes = volumes
            .sorted { $0.value > $1.value }
            .map { (muscle: $0.key, volume: $0.value) }

        // Aggregates
        let trainedVolumes = volumes.values.filter { $0 > 0 }
        totalWeeklySets = trainedVolumes.reduce(0, +)
        trainedCount = trainedVolumes.count
        recoveredCount = fatigueStates.filter(\.isRecovered).count
        overworkedMuscles = fatigueStates.filter(\.isOverworked).map(\.muscle)

        // Next recovery
        let upcoming = fatigueStates
            .compactMap { state -> (MuscleGroup, Date)? in
                guard let date = state.nextReadyDate else { return nil }
                return (state.muscle, date)
            }
            .sorted { $0.1 < $1.1 }
        nextRecovery = upcoming.first.map { (muscle: $0.0, date: $0.1) }

        // Balance
        balanceInfo = computeBalance(volumes: trainedVolumes)
    }

    // MARK: - Balance

    struct BalanceInfo: Sendable {
        let isBalanced: Bool
        let ratio: Double
        let undertrainedMuscles: [MuscleGroup]

        static let noData = BalanceInfo(isBalanced: true, ratio: 0, undertrainedMuscles: [])
    }

    private func computeBalance(volumes: [Int]) -> BalanceInfo {
        guard !volumes.isEmpty else { return .noData }
        let avg = Double(volumes.reduce(0, +)) / Double(volumes.count)
        let maxV = volumes.max() ?? 1
        let minV = volumes.min() ?? 0
        let ratio = avg > 0 ? Double(maxV - minV) / avg : 0
        guard ratio.isFinite, !ratio.isNaN else { return .noData }

        let isBalanced = ratio < 1.5
        let goalHalf = weeklySetGoal / 2
        let undertrained = sortedMuscleVolumes
            .suffix(3)
            .filter { $0.volume < goalHalf && $0.volume > 0 }
            .map(\.muscle)

        return BalanceInfo(isBalanced: isBalanced, ratio: ratio, undertrainedMuscles: undertrained)
    }
}

// MARK: - Helpers

private extension Int {
    func clamped(to range: ClosedRange<Int>, fallback: Int) -> Int {
        self == 0 ? fallback : Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
