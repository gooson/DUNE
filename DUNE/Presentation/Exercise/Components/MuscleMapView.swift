import SwiftUI
import SwiftData

struct MuscleMapView: View {
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var records: [ExerciseRecord]

    @State private var selectedMuscle: MuscleGroup?

    private var weeklyVolume: [MuscleGroup: Int] {
        records.weeklyMuscleVolume()
    }

    private var maxVolume: Int {
        weeklyVolume.values.max() ?? 1
    }

    private var trainedMuscleCount: Int {
        weeklyVolume.values.filter { $0 > 0 }.count
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack {
                Text(trainedMuscleCount == 0 ? "Start recording workouts to populate the map" : "\(trainedMuscleCount) muscles trained this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: DS.Spacing.sm) {
                bodyDiagram(isFront: true)
                    .frame(maxWidth: 170)
                bodyDiagram(isFront: false)
                    .frame(maxWidth: 170)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            legendView

            if let muscle = selectedMuscle {
                muscleDetail(muscle)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .navigationTitle("Muscle Map")
        .navigationBarTitleDisplayMode(.inline)
        .background { DetailWaveBackground() }
    }

    // MARK: - Body Map

    private func bodyDiagram(isFront: Bool) -> some View {
        let parts = isFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = isFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape
        let aspectRatio: CGFloat = 200.0 / 400.0

        return GeometryReader { geo in
            let size = geo.size
            let outlineBounds = outlineShape.path(in: CGRect(origin: .zero, size: size)).boundingRect
            let centerOffsetX = (size.width - outlineBounds.width) / 2 - outlineBounds.minX

            ZStack {
                outlineShape
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: size.width, height: size.height)

                ForEach(parts) { part in
                    Button {
                        withAnimation(DS.Animation.snappy) {
                            selectedMuscle = selectedMuscle == part.muscle ? nil : part.muscle
                        }
                    } label: {
                        part.shape
                            .fill(muscleColor(for: part.muscle))
                            .overlay {
                                part.shape
                                    .stroke(strokeColor(for: part.muscle), lineWidth: selectedMuscle == part.muscle ? 2 : 0.5)
                            }
                            .frame(width: size.width, height: size.height)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: size.width, height: size.height)
            .offset(x: centerOffsetX)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxHeight: 320)
        .clipped()
    }

    private func normalizedIntensity(for muscle: MuscleGroup) -> Double {
        guard maxVolume > 0 else { return 0 }
        let volume = weeklyVolume[muscle] ?? 0
        return min(1.0, Double(volume) / Double(maxVolume))
    }

    private func muscleColor(for muscle: MuscleGroup) -> Color {
        muscleColor(intensity: normalizedIntensity(for: muscle))
    }

    private func muscleColor(intensity: Double) -> Color {
        if intensity <= 0 { return Color.secondary.opacity(0.08) }
        return DS.Color.activity.opacity(0.2 + intensity * 0.6)
    }

    private func strokeColor(for muscle: MuscleGroup) -> Color {
        selectedMuscle == muscle ? DS.Color.activity : Color.secondary.opacity(0.2)
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: DS.Spacing.lg) {
            legendItem(label: "None", intensity: 0)
            legendItem(label: "Low", intensity: 0.3)
            legendItem(label: "Medium", intensity: 0.6)
            legendItem(label: "High", intensity: 1.0)
        }
    }

    private func legendItem(label: String, intensity: Double) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: 3)
                .fill(muscleColor(intensity: intensity))
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Muscle Detail

    private func muscleDetail(_ muscle: MuscleGroup) -> some View {
        let volume = weeklyVolume[muscle] ?? 0
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(muscle.displayName)
                    .font(.headline)
                Spacer()
                Text("\(volume) sets this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Volume bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                    if maxVolume > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DS.Color.activity)
                            .frame(width: geo.size.width * CGFloat(volume) / CGFloat(maxVolume))
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.horizontal, DS.Spacing.lg)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
