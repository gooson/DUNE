import SwiftUI

/// Body diagram with recovery/volume coloring — front and back side by side.
/// Segmented picker to switch between Recovery and Volume modes.
/// Uses original outline + muscle paths from react-native-body-highlighter (MIT).
struct MuscleRecoveryMapView: View {
    let fatigueStates: [MuscleFatigueState]
    var isExpanded: Bool = false
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
    @State private var recoveredCount = 0
    @State private var trainedCount = 0

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
        recoveredCount = fatigueStates.filter(\.isRecovered).count
        trainedCount = fatigueStates.filter { $0.weeklyVolume > 0 }.count
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Button {
                switch mode {
                case .recovery: showingRecoveryInfoSheet = true
                case .volume: showingVolumeInfoSheet = true
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Mode", selection: $mode) {
                ForEach(MapMode.allCases, id: \.rawValue) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)
        }
        .sheet(isPresented: $showingRecoveryInfoSheet) {
            FatigueAlgorithmSheet()
        }
        .sheet(isPresented: $showingVolumeInfoSheet) {
            VolumeAlgorithmSheet()
        }
    }

    private var subtitle: String {
        switch mode {
        case .recovery:
            let total = fatigueStates.count
            guard total > 0 else { return "Start training to track recovery" }
            if recoveredCount == total { return "All \(total) muscle groups ready" }
            return "\(recoveredCount)/\(total) muscle groups ready"
        case .volume:
            guard trainedCount > 0 else { return "Start recording workouts to see volume" }
            return "\(trainedCount) muscles trained this week"
        }
    }

    // MARK: - Body Diagram

    private var bodyDiagramSection: some View {
        let maxDiagramWidth: CGFloat = isExpanded ? 220 : 170

        return VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                bodyDiagram(isFront: true)
                    .frame(maxWidth: maxDiagramWidth)
                bodyDiagram(isFront: false)
                    .frame(maxWidth: maxDiagramWidth)
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
                        let colors = muscleColors(for: part.muscle)
                        part.shape
                            .fill(colors.fill)
                            .overlay {
                                part.shape
                                    .stroke(colors.stroke, lineWidth: 0.5)
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
        .frame(maxHeight: isExpanded ? 400 : 300)
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

    private func muscleColors(for muscle: MuscleGroup) -> (fill: Color, stroke: Color) {
        switch mode {
        case .recovery:
            return (recoveryColor(for: muscle), recoveryStrokeColor(for: muscle))
        case .volume:
            let intensity = VolumeIntensity.from(sets: fatigueByMuscle[muscle]?.weeklyVolume ?? 0)
            return (intensity.color, intensity.strokeColor)
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
}
