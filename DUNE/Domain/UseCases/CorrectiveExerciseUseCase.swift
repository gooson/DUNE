import Foundation

/// Recommends corrective exercises based on posture assessment results.
///
/// Maps posture metric issues (caution/warning) to curated exercise IDs from the library,
/// prioritizes by severity, and deduplicates exercises that help multiple metrics.
struct CorrectiveExerciseUseCase: Sendable {

    private let library: ExerciseLibraryQuerying

    init(library: ExerciseLibraryQuerying) {
        self.library = library
    }

    // MARK: - Public

    /// Returns up to `limit` corrective exercise recommendations for the given metrics.
    /// Only metrics with `caution` or `warning` status produce recommendations.
    func recommendations(
        for metrics: [PostureMetricResult],
        limit: Int = 8
    ) -> [CorrectiveRecommendation] {
        let issueMetrics = metrics.filter { $0.status == .caution || $0.status == .warning }
        guard !issueMetrics.isEmpty else { return [] }

        // Sort issues: warning first, then by score weight descending
        let sortedIssues = issueMetrics.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .warning
            }
            return lhs.type.scoreWeight > rhs.type.scoreWeight
        }

        // Build exercise → target metrics + best priority
        var exerciseMap: [String: (metrics: [PostureMetricType], priority: Int)] = [:]

        for (index, issue) in sortedIssues.enumerated() {
            let exerciseIDs = Self.correctiveExerciseIDs(for: issue.type)
            for exerciseID in exerciseIDs {
                if var existing = exerciseMap[exerciseID] {
                    existing.metrics.append(issue.type)
                    existing.priority = min(existing.priority, index)
                    exerciseMap[exerciseID] = existing
                } else {
                    exerciseMap[exerciseID] = (metrics: [issue.type], priority: index)
                }
            }
        }

        // Resolve exercise definitions and build recommendations
        var recommendations: [CorrectiveRecommendation] = []

        for (exerciseID, entry) in exerciseMap {
            guard let exercise = library.exercise(byID: exerciseID) else { continue }
            recommendations.append(CorrectiveRecommendation(
                id: exerciseID,
                exercise: exercise,
                targetMetrics: entry.metrics,
                priority: entry.priority
            ))
        }

        // Sort: lower priority number first, then bodyweight equipment first for accessibility
        recommendations.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            if lhs.exercise.equipment != rhs.exercise.equipment {
                return lhs.exercise.equipment == .bodyweight
            }
            return lhs.exercise.name < rhs.exercise.name
        }

        return Array(recommendations.prefix(limit))
    }

    // MARK: - Mapping

    /// Curated exercise IDs for each posture metric type.
    static func correctiveExerciseIDs(for metricType: PostureMetricType) -> [String] {
        switch metricType {
        case .forwardHead:
            return ["stretching", "mobility-work", "yoga"]
        case .roundedShoulders:
            return ["band-pull-apart", "reverse-fly", "face-pull"]
        case .thoracicKyphosis:
            return ["foam-rolling", "yoga", "dead-bug"]
        case .kneeHyperextension:
            return ["stretching", "bodyweight-squat", "glute-bridge"]
        case .shoulderAsymmetry:
            return ["band-pull-apart", "mobility-work"]
        case .hipAsymmetry:
            return ["glute-bridge-unilateral", "plank", "dead-bug"]
        case .kneeAlignment:
            return ["bodyweight-squat", "glute-bridge", "stretching"]
        case .lateralShift:
            return ["plank", "dead-bug", "glute-bridge"]
        }
    }
}
