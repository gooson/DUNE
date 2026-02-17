import SwiftUI

/// Service for rendering a WorkoutShareCard into a shareable UIImage.
/// Pure Presentation utility — no SwiftData or HealthKit dependency.
@MainActor
enum WorkoutShareService {

    /// Render a WorkoutShareCard to UIImage for sharing.
    /// Returns nil if rendering fails.
    static func renderShareImage(data: WorkoutShareData, weightUnit: WeightUnit) -> UIImage? {
        let card = WorkoutShareCard(data: data, weightUnit: weightUnit)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0 // Retina quality
        return renderer.uiImage
    }

    /// Build WorkoutShareData from an ExerciseRecord and its completed sets.
    static func buildShareData(
        from record: ExerciseRecordShareInput,
        personalBest: String? = nil
    ) -> WorkoutShareData {
        let sets = record.completedSets.map { set in
            WorkoutShareData.SetInfo(
                setNumber: set.setNumber,
                weight: set.weight,
                reps: set.reps,
                duration: set.duration,
                distance: set.distance,
                setType: set.setType
            )
        }

        return WorkoutShareData(
            exerciseName: record.exerciseType,
            date: record.date,
            sets: sets,
            duration: record.duration,
            estimatedCalories: record.bestCalories,
            personalBest: personalBest,
            exerciseIcon: WorkoutSummary.iconName(for: record.exerciseType)
        )
    }
}

/// Lightweight input struct to avoid coupling share service to SwiftData ExerciseRecord directly.
/// Built in the View layer from @Model objects.
struct ExerciseRecordShareInput: Sendable {
    let exerciseType: String
    let date: Date
    let duration: TimeInterval
    let bestCalories: Double?
    let completedSets: [SetInput]

    struct SetInput: Sendable {
        let setNumber: Int
        let weight: Double?
        let reps: Int?
        let duration: TimeInterval?
        let distance: Double?
        let setType: SetType
    }
}
