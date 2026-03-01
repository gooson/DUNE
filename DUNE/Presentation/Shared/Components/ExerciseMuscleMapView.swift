import SwiftUI

/// Compact muscle map showing primary/secondary muscles for a specific exercise.
/// Displays front and back body views side by side.
struct ExerciseMuscleMapView: View {
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]

    private var primarySet: Set<MuscleGroup> { Set(primaryMuscles) }
    private var secondarySet: Set<MuscleGroup> { Set(secondaryMuscles) }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            bodyView(isFront: true, label: "Front")
            bodyView(isFront: false, label: "Back")
        }
        .frame(height: 170)
    }

    private func bodyView(isFront: Bool, label: String) -> some View {
        let parts = isFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = isFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape
        let aspectRatio: CGFloat = 200.0 / 400.0

        return VStack(spacing: DS.Spacing.xxs) {
            GeometryReader { geo in
                let size = geo.size
                let outlineBounds = outlineShape.path(in: CGRect(origin: .zero, size: size)).boundingRect
                let centerOffsetX = (size.width - outlineBounds.width) / 2 - outlineBounds.minX

                ZStack {
                    outlineShape
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.2)
                        .frame(width: size.width, height: size.height)

                    ForEach(parts) { part in
                        part.shape
                            .fill(colorForMuscle(part.muscle))
                            .overlay {
                                part.shape
                                    .stroke(strokeColorForMuscle(part.muscle), lineWidth: 0.5)
                            }
                            .frame(width: size.width, height: size.height)
                    }
                }
                .frame(width: size.width, height: size.height)
                .offset(x: centerOffsetX)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipped()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func colorForMuscle(_ muscle: MuscleGroup) -> Color {
        if primarySet.contains(muscle) {
            return DS.Color.activity.opacity(0.7)
        } else if secondarySet.contains(muscle) {
            return DS.Color.activity.opacity(0.25)
        }
        return Color.secondary.opacity(0.06)
    }

    private func strokeColorForMuscle(_ muscle: MuscleGroup) -> Color {
        if primarySet.contains(muscle) {
            return DS.Color.activity.opacity(0.45)
        } else if secondarySet.contains(muscle) {
            return DS.Color.activity.opacity(0.25)
        }
        return Color.secondary.opacity(0.12)
    }
}

#Preview("Bench Press") {
    ExerciseMuscleMapView(
        primaryMuscles: [.chest],
        secondaryMuscles: [.triceps, .shoulders]
    )
    .padding()
}

#Preview("Deadlift") {
    ExerciseMuscleMapView(
        primaryMuscles: [.back, .hamstrings, .glutes],
        secondaryMuscles: [.quadriceps, .core, .forearms, .traps]
    )
    .padding()
}
