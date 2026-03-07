import SwiftUI

/// Service for rendering a WorkoutShareCard into a shareable UIImage.
/// Pure Presentation utility — no SwiftData or HealthKit dependency.
@MainActor
enum WorkoutShareService {
    static let renderWidth: CGFloat = 360

    /// Render a WorkoutShareCard to UIImage for sharing.
    /// Returns nil if rendering fails.
    static func renderShareImage(data: WorkoutShareData, weightUnit: WeightUnit) -> UIImage? {
        let renderSize = measuredRenderSize(data: data, weightUnit: weightUnit)
        guard renderSize.width > 0, renderSize.height > 0 else {
            AppLogger.ui.error("Workout share image skipped because measured size was invalid: \(renderSize.debugDescription)")
            return nil
        }

        let card = renderableCard(data: data, weightUnit: weightUnit)
            .frame(width: renderSize.width, height: renderSize.height, alignment: .topLeading)
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = .init(width: renderSize.width, height: renderSize.height)
        renderer.scale = 3.0 // Retina quality
        return renderer.uiImage
    }

    static func measuredRenderSize(data: WorkoutShareData, weightUnit: WeightUnit) -> CGSize {
        let hostingController = UIHostingController(rootView: renderableCard(data: data, weightUnit: weightUnit))
        let measured = hostingController.sizeThatFits(
            in: CGSize(width: renderWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(
            width: ceil(max(0, measured.width)),
            height: ceil(max(0, measured.height))
        )
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
            exerciseIcon: WorkoutActivityType.infer(from: record.exerciseType)?.iconName ?? "figure.mixed.cardio"
        )
    }

    private static func renderableCard(data: WorkoutShareData, weightUnit: WeightUnit) -> some View {
        WorkoutShareCard(data: data, weightUnit: weightUnit)
            .frame(width: renderWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
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
