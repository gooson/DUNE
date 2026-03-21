import Foundation

/// A recommended corrective exercise for addressing a posture issue.
struct CorrectiveRecommendation: Sendable, Identifiable, Hashable {
    let id: String
    let exercise: ExerciseDefinition
    let targetMetrics: [PostureMetricType]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CorrectiveRecommendation, rhs: CorrectiveRecommendation) -> Bool {
        lhs.id == rhs.id
    }
}
