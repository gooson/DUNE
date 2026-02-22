import SwiftUI

/// Body diagram with recovery coloring — front and back side by side.
/// Uses original outline + muscle paths from react-native-body-highlighter (MIT).
struct MuscleRecoveryMapView: View {
    let fatigueStates: [MuscleFatigueState]
    let onMuscleSelected: (MuscleGroup) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] = [:]
    @State private var showingAlgorithmSheet = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            headerSection
            bodyDiagramSection
        }
        .onAppear { rebuildFatigueIndex() }
        .onChange(of: fatigueStates.count) { _, _ in rebuildFatigueIndex() }
    }

    private func rebuildFatigueIndex() {
        fatigueByMuscle = Dictionary(uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) })
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(recoverySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showingAlgorithmSheet = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showingAlgorithmSheet) {
                FatigueAlgorithmSheet()
            }

            Spacer()
        }
    }

    private var recoverySubtitle: String {
        let recovered = fatigueStates.filter(\.isRecovered).count
        let total = fatigueStates.count
        guard total > 0 else { return "Start training to track recovery" }
        if recovered == total { return "All \(total) muscle groups ready" }
        return "\(recovered)/\(total) muscle groups ready"
    }

    // MARK: - Body Diagram

    private var bodyDiagramSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                bodyDiagram(isFront: true)
                bodyDiagram(isFront: false)
            }
            legendRow
        }
    }

    private func bodyDiagram(isFront: Bool) -> some View {
        let parts = isFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = isFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape
        // Original renders at 200x400 (1:2 aspect)
        let aspectRatio: CGFloat = 200.0 / 400.0

        return GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Body outline from original SVG
                outlineShape
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: width, height: height)

                // Muscle parts with recovery coloring
                ForEach(parts) { part in
                    Button {
                        onMuscleSelected(part.muscle)
                    } label: {
                        part.shape
                            .fill(recoveryColor(for: part.muscle))
                            .overlay {
                                part.shape
                                    .stroke(recoveryStrokeColor(for: part.muscle), lineWidth: 0.5)
                            }
                            .frame(width: width, height: height)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxHeight: 300)
        .clipped()
    }

    // MARK: - Legend

    private var legendRow: some View {
        FatigueLegendView(onTap: { showingAlgorithmSheet = true })
    }

    // MARK: - Colors

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
