import SwiftUI

struct VisionExerciseMuscleMapView: View {
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]

    private var primarySet: Set<MuscleGroup> { Set(primaryMuscles) }
    private var secondarySet: Set<MuscleGroup> { Set(secondaryMuscles) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                bodyView(isFront: true, label: "Front")
                bodyView(isFront: false, label: "Rear")
            }

            HStack(spacing: 16) {
                legendItem(title: "Primary", color: Color.accentColor.opacity(0.72))
                legendItem(title: "Secondary", color: Color.cyan.opacity(0.38))
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func bodyView(isFront: Bool, label: LocalizedStringKey) -> some View {
        let parts = isFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = isFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape
        let aspectRatio: CGFloat = 200.0 / 400.0

        return VStack(spacing: 8) {
            GeometryReader { geometry in
                let size = geometry.size
                let outlineBounds = outlineShape.path(in: CGRect(origin: .zero, size: size)).boundingRect
                let centerOffsetX = (size.width - outlineBounds.width) / 2 - outlineBounds.minX

                ZStack {
                    outlineShape
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                        .frame(width: size.width, height: size.height)

                    ForEach(parts) { part in
                        part.shape
                            .fill(fillColor(for: part.muscle))
                            .overlay {
                                part.shape
                                    .stroke(strokeColor(for: part.muscle), lineWidth: 0.55)
                            }
                            .frame(width: size.width, height: size.height)
                    }
                }
                .frame(width: size.width, height: size.height)
                .offset(x: centerOffsetX)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)

            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func legendItem(title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func fillColor(for muscle: MuscleGroup) -> Color {
        if primarySet.contains(muscle) {
            return Color.accentColor.opacity(0.72)
        }
        if secondarySet.contains(muscle) {
            return Color.cyan.opacity(0.38)
        }
        return Color.white.opacity(0.05)
    }

    private func strokeColor(for muscle: MuscleGroup) -> Color {
        if primarySet.contains(muscle) {
            return Color.accentColor.opacity(0.46)
        }
        if secondarySet.contains(muscle) {
            return Color.cyan.opacity(0.24)
        }
        return Color.white.opacity(0.08)
    }
}
