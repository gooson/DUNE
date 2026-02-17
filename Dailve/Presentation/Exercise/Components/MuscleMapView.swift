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
                bodyOutline(width: w, height: h)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)

                // Muscle groups
                let muscles = showingFront ? frontMuscles : backMuscles
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

    private func bodyOutline(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let cx = width * 0.5
        // Head
        path.addEllipse(in: CGRect(x: cx - 18, y: height * 0.02, width: 36, height: 42))
        // Neck
        path.addRect(CGRect(x: cx - 8, y: height * 0.1, width: 16, height: height * 0.03))
        // Torso
        path.addRoundedRect(in: CGRect(x: cx - width * 0.18, y: height * 0.13, width: width * 0.36, height: height * 0.32), cornerSize: CGSize(width: 12, height: 12))
        // Left arm
        path.addRoundedRect(in: CGRect(x: cx - width * 0.3, y: height * 0.15, width: width * 0.1, height: height * 0.28), cornerSize: CGSize(width: 8, height: 8))
        // Right arm
        path.addRoundedRect(in: CGRect(x: cx + width * 0.2, y: height * 0.15, width: width * 0.1, height: height * 0.28), cornerSize: CGSize(width: 8, height: 8))
        // Left leg
        path.addRoundedRect(in: CGRect(x: cx - width * 0.14, y: height * 0.47, width: width * 0.12, height: height * 0.38), cornerSize: CGSize(width: 8, height: 8))
        // Right leg
        path.addRoundedRect(in: CGRect(x: cx + width * 0.02, y: height * 0.47, width: width * 0.12, height: height * 0.38), cornerSize: CGSize(width: 8, height: 8))
        return path
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

// MARK: - Muscle Map Data

private struct MuscleMapItem {
    let muscle: MuscleGroup
    let position: CGPoint  // Normalized (0...1)
    let size: CGSize       // Normalized (0...1)
    let cornerRadius: CGFloat
}

// Front view muscle positions (normalized coordinates)
private let frontMuscles: [MuscleMapItem] = [
    // Chest
    MuscleMapItem(muscle: .chest, position: CGPoint(x: 0.42, y: 0.21), size: CGSize(width: 0.12, height: 0.08), cornerRadius: 6),
    MuscleMapItem(muscle: .chest, position: CGPoint(x: 0.58, y: 0.21), size: CGSize(width: 0.12, height: 0.08), cornerRadius: 6),
    // Shoulders
    MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.33, y: 0.16), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
    MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.67, y: 0.16), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
    // Biceps
    MuscleMapItem(muscle: .biceps, position: CGPoint(x: 0.27, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
    MuscleMapItem(muscle: .biceps, position: CGPoint(x: 0.73, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
    // Forearms
    MuscleMapItem(muscle: .forearms, position: CGPoint(x: 0.25, y: 0.38), size: CGSize(width: 0.05, height: 0.08), cornerRadius: 4),
    MuscleMapItem(muscle: .forearms, position: CGPoint(x: 0.75, y: 0.38), size: CGSize(width: 0.05, height: 0.08), cornerRadius: 4),
    // Abs
    MuscleMapItem(muscle: .core, position: CGPoint(x: 0.5, y: 0.33), size: CGSize(width: 0.12, height: 0.12), cornerRadius: 6),
    // Quads
    MuscleMapItem(muscle: .quadriceps, position: CGPoint(x: 0.42, y: 0.55), size: CGSize(width: 0.1, height: 0.14), cornerRadius: 6),
    MuscleMapItem(muscle: .quadriceps, position: CGPoint(x: 0.58, y: 0.55), size: CGSize(width: 0.1, height: 0.14), cornerRadius: 6),
    // Calves (front)
    MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.42, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
    MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.58, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
]

// Back view muscle positions
private let backMuscles: [MuscleMapItem] = [
    // Traps
    MuscleMapItem(muscle: .traps, position: CGPoint(x: 0.5, y: 0.15), size: CGSize(width: 0.16, height: 0.06), cornerRadius: 6),
    // Rear delts
    MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.33, y: 0.17), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
    MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.67, y: 0.17), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
    // Lats
    MuscleMapItem(muscle: .lats, position: CGPoint(x: 0.4, y: 0.26), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 8),
    MuscleMapItem(muscle: .lats, position: CGPoint(x: 0.6, y: 0.26), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 8),
    // Triceps
    MuscleMapItem(muscle: .triceps, position: CGPoint(x: 0.27, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
    MuscleMapItem(muscle: .triceps, position: CGPoint(x: 0.73, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
    // Lower back
    MuscleMapItem(muscle: .back, position: CGPoint(x: 0.5, y: 0.37), size: CGSize(width: 0.14, height: 0.08), cornerRadius: 6),
    // Glutes
    MuscleMapItem(muscle: .glutes, position: CGPoint(x: 0.42, y: 0.48), size: CGSize(width: 0.1, height: 0.08), cornerRadius: 8),
    MuscleMapItem(muscle: .glutes, position: CGPoint(x: 0.58, y: 0.48), size: CGSize(width: 0.1, height: 0.08), cornerRadius: 8),
    // Hamstrings
    MuscleMapItem(muscle: .hamstrings, position: CGPoint(x: 0.42, y: 0.6), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 6),
    MuscleMapItem(muscle: .hamstrings, position: CGPoint(x: 0.58, y: 0.6), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 6),
    // Calves (back)
    MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.42, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
    MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.58, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
]
