import SwiftUI

/// Compact muscle map showing primary/secondary muscles for a specific exercise.
/// Displays front and back body views side by side.
struct ExerciseMuscleMapView: View {
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]

    private var primarySet: Set<MuscleGroup> { Set(primaryMuscles) }
    private var secondarySet: Set<MuscleGroup> { Set(secondaryMuscles) }

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            bodyView(muscles: MuscleMapData.frontMuscles, label: "전면")
            bodyView(muscles: MuscleMapData.backMuscles, label: "후면")
        }
        .frame(height: 160)
    }

    private func bodyView(muscles: [MuscleMapItem], label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    MuscleMapData.bodyOutline(width: w, height: h)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)

                    ForEach(muscles) { item in
                        RoundedRectangle(cornerRadius: item.cornerRadius)
                            .fill(colorForMuscle(item.muscle))
                            .frame(
                                width: item.size.width * w,
                                height: item.size.height * h
                            )
                            .position(
                                x: item.position.x * w,
                                y: item.position.y * h
                            )
                    }
                }
            }

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
