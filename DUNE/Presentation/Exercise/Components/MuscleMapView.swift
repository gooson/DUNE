import SwiftUI
import SwiftData

struct MuscleMapView: View {
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var records: [ExerciseRecord]

    @State private var showingFront = true
    @State private var selectedMuscle: MuscleGroup?

    private var weeklyVolume: [MuscleGroup: Int] {
        records.weeklyMuscleVolume()
    }

    private var maxVolume: Int {
        weeklyVolume.values.max() ?? 1
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Toggle front/back
            Picker("View", selection: $showingFront) {
                Text("Front").tag(true)
                Text("Back").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Spacing.xl)

            // Body map
            bodyMap
                .frame(height: 400)
                .padding(.horizontal, DS.Spacing.xl)

            // Legend
            legendView

            // Muscle detail
            if let muscle = selectedMuscle {
                muscleDetail(muscle)
            }
        }
        .navigationTitle("Muscle Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Body Map

    private var bodyMap: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Body outline
                MuscleMapData.bodyOutline(width: w, height: h)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)

                // Muscle groups
                let muscles = showingFront ? MuscleMapData.frontMuscles : MuscleMapData.backMuscles
                ForEach(muscles, id: \.muscle) { item in
                    muscleShape(item: item, width: w, height: h)
                }
            }
        }
    }

    private func muscleShape(item: MuscleMapItem, width: CGFloat, height: CGFloat) -> some View {
        let volume = weeklyVolume[item.muscle] ?? 0
        let intensity = maxVolume > 0 ? Double(volume) / Double(maxVolume) : 0

        return RoundedRectangle(cornerRadius: item.cornerRadius)
            .fill(muscleColor(intensity: intensity))
            .frame(width: item.size.width * width, height: item.size.height * height)
            .position(x: item.position.x * width, y: item.position.y * height)
            .onTapGesture {
                withAnimation(DS.Animation.snappy) {
                    selectedMuscle = selectedMuscle == item.muscle ? nil : item.muscle
                }
            }
            .overlay {
                if selectedMuscle == item.muscle {
                    RoundedRectangle(cornerRadius: item.cornerRadius)
                        .stroke(DS.Color.activity, lineWidth: 2)
                        .frame(width: item.size.width * width, height: item.size.height * height)
                        .position(x: item.position.x * width, y: item.position.y * height)
                }
            }
    }

    private func muscleColor(intensity: Double) -> Color {
        if intensity <= 0 { return Color.secondary.opacity(0.08) }
        return DS.Color.activity.opacity(0.2 + intensity * 0.6)
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

