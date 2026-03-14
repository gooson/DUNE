import Foundation

/// Lightweight snapshot of a WorkoutTemplate's exercise composition for overlap comparison.
/// Avoids importing SwiftData in the Domain layer.
struct TemplateSnapshot: Sendable {
    let exerciseDefinitionIDs: Set<String>

    init(exerciseDefinitionIDs: [String]) {
        self.exerciseDefinitionIDs = Set(exerciseDefinitionIDs.map { $0.lowercased() })
    }
}

/// Checks whether a recommended workout sequence already overlaps with an existing template.
struct TemplateOverlapChecker: Sendable {
    /// Overlap threshold — recommendations with >= 80% overlap are considered already covered.
    static let overlapThreshold: Double = 0.8

    /// Returns true if any existing template covers the recommendation's exercise sequence.
    static func isAlreadyCovered(
        recommendation: WorkoutTemplateRecommendation,
        existingTemplates: [TemplateSnapshot]
    ) -> Bool {
        let recommendationLabels = Set(recommendation.sequenceLabels.map { $0.lowercased() })
        guard !recommendationLabels.isEmpty else { return false }

        for template in existingTemplates {
            let templateIDs = template.exerciseDefinitionIDs
            guard !templateIDs.isEmpty else { continue }

            let intersection = recommendationLabels.intersection(templateIDs)
            let union = recommendationLabels.union(templateIDs)
            let overlap = Double(intersection.count) / Double(union.count)

            if overlap >= overlapThreshold {
                return true
            }
        }
        return false
    }
}
