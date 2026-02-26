import SwiftUI

/// Body diagram with recovery/volume coloring — front and back side by side.
/// Segmented picker to switch between Recovery and Volume modes.
/// Uses original outline + muscle paths from react-native-body-highlighter (MIT).
struct MuscleRecoveryMapView: View {
    let fatigueStates: [MuscleFatigueState]
    let onMuscleSelected: (MuscleGroup) -> Void

    // MARK: - Mode

    enum MapMode: Int, CaseIterable {
        case recovery
        case volume

        var label: String {
            switch self {
            case .recovery: "Recovery"
            case .volume: "Volume"
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @State private var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] = [:]
    @State private var mode: MapMode = .recovery
    @State private var showingRecoveryInfoSheet = false
    @State private var showingVolumeInfoSheet = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            headerSection
            bodyDiagramSection
        }
        .animation(.easeInOut(duration: 0.3), value: mode)
        .onAppear { rebuildFatigueIndex() }
        .onChange(of: fatigueStates.count) { _, _ in rebuildFatigueIndex() }
    }

    private func rebuildFatigueIndex() {
        fatigueByMuscle = Dictionary(uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) })
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Picker("Mode", selection: $mode) {
                    ForEach(MapMode.allCases, id: \.rawValue) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer()

                infoButton
            }

            HStack {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
            }
        }
    }

    private var subtitle: String {
        switch mode {
        case .recovery:
            let recovered = fatigueStates.filter(\.isRecovered).count
            let total = fatigueStates.count
            guard total > 0 else { return "Start training to track recovery" }
            if recovered == total { return "All \(total) muscle groups ready" }
            return "\(recovered)/\(total) muscle groups ready"
        case .volume:
            let trained = fatigueStates.filter { $0.weeklyVolume > 0 }.count
            guard trained > 0 else { return "Start recording workouts to see volume" }
            return "\(trained) muscles trained this week"
        }
    }

    @ViewBuilder
    private var infoButton: some View {
        switch mode {
        case .recovery:
            Button { showingRecoveryInfoSheet = true } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showingRecoveryInfoSheet) {
                FatigueAlgorithmSheet()
            }
        case .volume:
            Button { showingVolumeInfoSheet = true } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showingVolumeInfoSheet) {
                VolumeAlgorithmSheet()
            }
        }
    }

    // MARK: - Body Diagram

    private var bodyDiagramSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                bodyDiagram(isFront: true)
                    .frame(maxWidth: 170)
                bodyDiagram(isFront: false)
                    .frame(maxWidth: 170)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            legendRow
        }
    }

    private func bodyDiagram(isFront: Bool) -> some View {
        let parts = isFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = isFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape
        // Original renders at 200x400 (1:2 aspect)
        let aspectRatio: CGFloat = 200.0 / 400.0

        return GeometryReader { geo in
            let size = geo.size
            // Center body content using outline's actual bounding box
            let outlineBounds = outlineShape.path(
                in: CGRect(origin: .zero, size: size)
            ).boundingRect
            let centerOffsetX = (size.width - outlineBounds.width) / 2 - outlineBounds.minX

            ZStack {
                // Body outline from original SVG
                outlineShape
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: size.width, height: size.height)

                // Muscle parts with mode-dependent coloring
                ForEach(parts) { part in
                    Button {
                        onMuscleSelected(part.muscle)
                    } label: {
                        part.shape
                            .fill(fillColor(for: part.muscle))
                            .overlay {
                                part.shape
                                    .stroke(strokeColor(for: part.muscle), lineWidth: 0.5)
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
        .frame(maxHeight: 300)
        .clipped()
    }

    // MARK: - Legend

    @ViewBuilder
    private var legendRow: some View {
        switch mode {
        case .recovery:
            FatigueLegendView(onTap: { showingRecoveryInfoSheet = true })
        case .volume:
            VolumeLegendView(onTap: { showingVolumeInfoSheet = true })
        }
    }

    // MARK: - Colors (mode-dependent)

    private func fillColor(for muscle: MuscleGroup) -> Color {
        switch mode {
        case .recovery:
            return recoveryColor(for: muscle)
        case .volume:
            return volumeColor(for: muscle)
        }
    }

    private func strokeColor(for muscle: MuscleGroup) -> Color {
        switch mode {
        case .recovery:
            return recoveryStrokeColor(for: muscle)
        case .volume:
            return volumeStrokeColor(for: muscle)
        }
    }

    // Recovery colors (existing logic)

    private func recoveryColor(for muscle: MuscleGroup) -> Color {
        guard let state = fatigueByMuscle[muscle] else {
            return FatigueLevel.noData.color(for: colorScheme)
        }
        return state.fatigueLevel.color(for: colorScheme)
    }

    private func recoveryStrokeColor(for muscle: MuscleGroup) -> Color {
        guard let state = fatigueByMuscle[muscle] else {
            return FatigueLevel.noData.strokeColor(for: colorScheme)
        }
        return state.fatigueLevel.strokeColor(for: colorScheme)
    }

    // Volume colors — absolute weekly sets threshold

    private func volumeColor(for muscle: MuscleGroup) -> Color {
        let volume = fatigueByMuscle[muscle]?.weeklyVolume ?? 0
        return VolumeIntensity.from(sets: volume).color
    }

    private func volumeStrokeColor(for muscle: MuscleGroup) -> Color {
        let volume = fatigueByMuscle[muscle]?.weeklyVolume ?? 0
        return VolumeIntensity.from(sets: volume).strokeColor
    }
}

// MARK: - Volume Intensity

/// 5-level volume intensity based on weekly set count.
enum VolumeIntensity: Int, CaseIterable {
    case none = 0
    case light = 1
    case moderate = 2
    case high = 3
    case veryHigh = 4

    static func from(sets: Int) -> VolumeIntensity {
        switch sets {
        case 0:     .none
        case 1...5: .light
        case 6...10: .moderate
        case 11...15: .high
        default:     .veryHigh
        }
    }

    var label: String {
        switch self {
        case .none:     "0"
        case .light:    "1-5"
        case .moderate: "6-10"
        case .high:     "11-15"
        case .veryHigh: "16+"
        }
    }

    var color: Color {
        switch self {
        case .none:     Color.secondary.opacity(0.08)
        case .light:    DS.Color.activity.opacity(0.2)
        case .moderate: DS.Color.activity.opacity(0.4)
        case .high:     DS.Color.activity.opacity(0.6)
        case .veryHigh: DS.Color.activity.opacity(0.8)
        }
    }

    var strokeColor: Color {
        switch self {
        case .none: Color.secondary.opacity(0.15)
        default:    color.opacity(0.6)
        }
    }
}
