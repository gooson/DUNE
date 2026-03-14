import Foundation
import Testing
@testable import DUNE

@Suite("TemplateOverlapChecker")
struct TemplateOverlapCheckerTests {
    private func recommendation(labels: [String]) -> WorkoutTemplateRecommendation {
        WorkoutTemplateRecommendation(
            id: "test",
            title: "Test",
            sequenceTypes: Array(repeating: .traditionalStrengthTraining, count: labels.count),
            sequenceLabels: labels,
            frequency: 3,
            averageDurationMinutes: 30,
            lastPerformedAt: Date(),
            score: 1.0
        )
    }

    @Test("No overlap returns false")
    func noOverlap() {
        let rec = recommendation(labels: ["bench-press", "squat", "deadlift"])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["pull-up", "row", "curl"])
        #expect(!TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }

    @Test("50% overlap returns false (below threshold)")
    func partialOverlap() {
        let rec = recommendation(labels: ["bench-press", "squat"])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["bench-press", "deadlift"])
        // intersection=1, union=3 → 33%
        #expect(!TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }

    @Test("100% overlap returns true")
    func fullOverlap() {
        let rec = recommendation(labels: ["bench-press", "squat", "deadlift"])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["bench-press", "squat", "deadlift"])
        #expect(TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }

    @Test("80% overlap returns true (at threshold)")
    func atThreshold() {
        // rec: 4 exercises, template: 4 exercises, 4 shared → intersection=4, union=4 → 100%
        // Need exactly 80%: intersection/union >= 0.8
        // rec: [A, B, C, D], template: [A, B, C, D, E] → intersection=4, union=5 → 80%
        let rec = recommendation(labels: ["a", "b", "c", "d"])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["a", "b", "c", "d", "e"])
        #expect(TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }

    @Test("40% overlap returns false (below threshold)")
    func belowThreshold() {
        // rec: [A, B, C], template: [A, B, D, E] → intersection=2, union=5 → 40%
        let rec = recommendation(labels: ["a", "b", "c"])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["a", "b", "d", "e"])
        #expect(!TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }

    @Test("Empty recommendation returns false")
    func emptyRecommendation() {
        let rec = recommendation(labels: [])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["bench-press"])
        #expect(!TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }

    @Test("No existing templates returns false")
    func noTemplates() {
        let rec = recommendation(labels: ["bench-press", "squat"])
        #expect(!TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: []))
    }

    @Test("Case-insensitive comparison")
    func caseInsensitive() {
        let rec = recommendation(labels: ["Bench-Press", "SQUAT"])
        let template = TemplateSnapshot(exerciseDefinitionIDs: ["bench-press", "squat"])
        #expect(TemplateOverlapChecker.isAlreadyCovered(recommendation: rec, existingTemplates: [template]))
    }
}
