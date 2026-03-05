import SwiftUI

/// Pseudo-3D muscle map that users can rotate by dragging horizontally.
struct MuscleMap3DView: View {
    let fatigueStates: [MuscleFatigueState]
    let highlightedMuscle: MuscleGroup?

    @Environment(\.colorScheme) private var colorScheme
    @State private var rotationY: Double = 0
    @State private var baseRotationY: Double = 0

    private var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] {
        Dictionary(uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) })
    }

    private var showingBack: Bool {
        let normalized = normalizedDegrees(rotationY)
        return normalized > 90 && normalized < 270
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Drag to rotate")
                .font(.footnote)
                .foregroundStyle(DS.Color.textSecondary)

            GeometryReader { geo in
                let width = min(geo.size.width, 300)
                let height = width * 2

                ZStack {
                    bodyFace(isFront: true)
                        .opacity(showingBack ? 0 : 1)
                        .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0), perspective: 0.75)

                    bodyFace(isFront: false)
                        .opacity(showingBack ? 1 : 0)
                        .rotation3DEffect(.degrees(rotationY + 180), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
                }
                .frame(width: width, height: height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 420)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        rotationY = baseRotationY + Double(value.translation.width * 0.45)
                    }
                    .onEnded { _ in
                        baseRotationY = rotationY
                    }
            )

            HStack {
                Image(systemName: showingBack ? "figure.stand.line.dotted.figure.stand" : "figure.stand")
                Text(showingBack ? "Back" : "Front")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Muscle Map 3D")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    withAnimation(DS.Animation.snappy) {
                        rotationY = 0
                        baseRotationY = 0
                    }
                }
            }
        }
    }

    private func bodyFace(isFront: Bool) -> some View {
        let parts = isFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = isFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape

        return GeometryReader { geo in
            let size = geo.size
            let outlineBounds = outlineShape.path(in: CGRect(origin: .zero, size: size)).boundingRect
            let centerOffsetX = (size.width - outlineBounds.width) / 2 - outlineBounds.minX

            ZStack {
                outlineShape
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: size.width, height: size.height)

                ForEach(parts) { part in
                    let colors = muscleColors(for: part.muscle)
                    part.shape
                        .fill(colors.fill)
                        .overlay {
                            part.shape
                                .stroke(colors.stroke, lineWidth: part.muscle == highlightedMuscle ? 2 : 0.6)
                        }
                        .frame(width: size.width, height: size.height)
                        .shadow(color: part.muscle == highlightedMuscle ? colors.stroke.opacity(0.5) : .clear, radius: 6)
                }
            }
            .frame(width: size.width, height: size.height)
            .offset(x: centerOffsetX)
        }
        .aspectRatio(200.0 / 400.0, contentMode: .fit)
        .frame(maxWidth: 220)
    }

    private func muscleColors(for muscle: MuscleGroup) -> (fill: Color, stroke: Color) {
        guard let state = fatigueByMuscle[muscle] else {
            return (
                FatigueLevel.noData.color(for: colorScheme),
                FatigueLevel.noData.strokeColor(for: colorScheme)
            )
        }

        return (
            state.fatigueLevel.color(for: colorScheme),
            state.fatigueLevel.strokeColor(for: colorScheme)
        )
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        let raw = degrees.truncatingRemainder(dividingBy: 360)
        return raw < 0 ? raw + 360 : raw
    }
}
