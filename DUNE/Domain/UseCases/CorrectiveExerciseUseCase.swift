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

        // Build exercise → target metrics + best priority index (lower = higher priority)
        var exerciseMap: [String: (metrics: [PostureMetricType], priority: Int)] = [:]

        for (index, issue) in sortedIssues.enumerated() {
            let exerciseIDs = Self.exerciseIDsByMetric[issue.type] ?? []
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

        // Resolve exercise definitions, sort, and build recommendations
        var resolved: [(id: String, exercise: ExerciseDefinition, metrics: [PostureMetricType], priority: Int)] = []

        for (exerciseID, entry) in exerciseMap {
            guard let exercise = library.exercise(byID: exerciseID) else { continue }
            resolved.append((id: exerciseID, exercise: exercise, metrics: entry.metrics, priority: entry.priority))
        }

        resolved.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            if lhs.exercise.equipment != rhs.exercise.equipment {
                return lhs.exercise.equipment == .bodyweight
            }
            return lhs.exercise.name < rhs.exercise.name
        }

        return resolved.prefix(limit).map {
            CorrectiveRecommendation(id: $0.id, exercise: $0.exercise, targetMetrics: $0.metrics)
        }
    }

    // MARK: - Mapping

    /// Curated exercise IDs for each posture metric type.
    /// IDs must match entries in exercises.json.
    static let exerciseIDsByMetric: [PostureMetricType: [String]] = [
        .forwardHead:        ["stretching", "mobility-work", "yoga"],
        .roundedShoulders:   ["band-pull-apart", "reverse-fly", "face-pull"],
        .thoracicKyphosis:   ["foam-rolling", "yoga", "dead-bug"],
        .kneeHyperextension: ["stretching", "bodyweight-squat", "glute-bridge"],
        .shoulderAsymmetry:  ["band-pull-apart", "mobility-work"],
        .hipAsymmetry:       ["glute-bridge-unilateral", "plank", "dead-bug"],
        .kneeAlignment:      ["bodyweight-squat", "glute-bridge", "stretching"],
        .lateralShift:       ["plank", "dead-bug", "glute-bridge"],
    ]
}
