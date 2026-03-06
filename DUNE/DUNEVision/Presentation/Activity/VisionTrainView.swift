import SwiftUI

struct VisionTrainView: View {
    private let fatigueStates: [MuscleFatigueState]
    private let onOpen3DCharts: () -> Void

    init(
        fatigueStates: [MuscleFatigueState] = VisionMuscleMapDemoData.fatigueStates,
        onOpen3DCharts: @escaping () -> Void = {}
    ) {
        self.fatigueStates = fatigueStates
        self.onOpen3DCharts = onOpen3DCharts
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroCard
                VisionMuscleMapExperienceView(
                    fatigueStates: fatigueStates,
                    initialMuscle: .back
                )
                statusNote
            }
            .padding(24)
        }
        .navigationTitle("Activity")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spatial Strength View")
                .font(.largeTitle.weight(.bold))

            Text("The shared iOS/visionOS muscle scene now uses SVG-extruded volumetric geometry. Spatial tap, orbit, and zoom are tuned for power users who want fast muscle-balance inspection.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    onOpen3DCharts()
                } label: {
                    Label("Open 3D Charts", systemImage: "chart.bar.3d.grouped")
                }

                Label("SVG → Volumetric Mesh", systemImage: "cube.transparent")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var statusNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Status")
                .font(.headline)
            Text("visionOS training sync is still using demo fatigue distribution. The geometry, selection, and spatial interaction pipeline are now shared with the iOS muscle map and ready for real exercise-record ingestion.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private enum VisionMuscleMapDemoData {
    static let fatigueStates: [MuscleFatigueState] = [
        makeState(.chest, weeklyVolume: 12, recoveryPercent: 0.52, hoursAgo: 18),
        makeState(.back, weeklyVolume: 16, recoveryPercent: 0.34, hoursAgo: 12),
        makeState(.shoulders, weeklyVolume: 9, recoveryPercent: 0.61, hoursAgo: 24),
        makeState(.biceps, weeklyVolume: 10, recoveryPercent: 0.73, hoursAgo: 30),
        makeState(.triceps, weeklyVolume: 8, recoveryPercent: 0.58, hoursAgo: 20),
        makeState(.quadriceps, weeklyVolume: 14, recoveryPercent: 0.41, hoursAgo: 16),
        makeState(.hamstrings, weeklyVolume: 11, recoveryPercent: 0.49, hoursAgo: 19),
        makeState(.glutes, weeklyVolume: 13, recoveryPercent: 0.45, hoursAgo: 17),
        makeState(.calves, weeklyVolume: 6, recoveryPercent: 0.79, hoursAgo: 40),
        makeState(.core, weeklyVolume: 7, recoveryPercent: 0.86, hoursAgo: 42),
        makeState(.forearms, weeklyVolume: 5, recoveryPercent: 0.83, hoursAgo: 46),
        makeState(.traps, weeklyVolume: 8, recoveryPercent: 0.64, hoursAgo: 27),
        makeState(.lats, weeklyVolume: 15, recoveryPercent: 0.38, hoursAgo: 14),
    ]

    private static func makeState(
        _ muscle: MuscleGroup,
        weeklyVolume: Int,
        recoveryPercent: Double,
        hoursAgo: Double
    ) -> MuscleFatigueState {
        let date = Date().addingTimeInterval(-(hoursAgo * 3600))
        return MuscleFatigueState(
            muscle: muscle,
            lastTrainedDate: date,
            hoursSinceLastTrained: hoursAgo,
            weeklyVolume: weeklyVolume,
            recoveryPercent: recoveryPercent,
            compoundScore: nil
        )
    }
}
