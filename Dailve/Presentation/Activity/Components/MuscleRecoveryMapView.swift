import SwiftUI

/// Hero section: SVG body diagram with recovery coloring + integrated workout suggestion.
/// Uses original outline + muscle paths from react-native-body-highlighter (MIT).
struct MuscleRecoveryMapView: View {
    let fatigueStates: [MuscleFatigueState]
    let suggestion: WorkoutSuggestion?
    let onStartExercise: (ExerciseDefinition) -> Void
    let onMuscleSelected: (MuscleGroup) -> Void

    @State private var showingFront = true
    @State private var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] = [:]

    var body: some View {
        HeroCard(tintColor: DS.Color.activity) {
            VStack(spacing: DS.Spacing.md) {
                headerSection
                bodyDiagramSection
                suggestionSection
            }
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
                Text("Muscle Recovery")
                    .font(.headline)
                Text(recoverySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Side", selection: $showingFront) {
                Text("Front").tag(true)
                Text("Back").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 130)
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
            bodyDiagram
            legendRow
        }
    }

    private var bodyDiagram: some View {
        let parts = showingFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let outlineShape = showingFront ? MuscleMapData.frontOutlineShape : MuscleMapData.backOutlineShape
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
        .frame(maxHeight: 380)
        .clipped()
        .padding(.horizontal, DS.Spacing.xxxl)
        .id(showingFront)
        .transition(.opacity)
        .animation(DS.Animation.standard, value: showingFront)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: DS.Spacing.md) {
            legendItem(color: .green.opacity(0.6), label: "Ready")
            legendItem(color: .yellow.opacity(0.65), label: "Recovering")
            legendItem(color: .red.opacity(0.55), label: "Fatigued")
            legendItem(color: .secondary.opacity(0.25), label: "No data")
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Suggestion

    @ViewBuilder
    private var suggestionSection: some View {
        if let suggestion {
            Divider().opacity(0.3)
            if suggestion.isRestDay {
                restDaySection(suggestion: suggestion)
            } else {
                workoutSection(suggestion: suggestion)
            }
        }
    }

    private func workoutSection(suggestion: WorkoutSuggestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(DS.Color.activity)
                Text("Suggested Workout")
                    .font(.subheadline.weight(.semibold))
            }

            if !suggestion.focusMuscles.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(suggestion.focusMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Color.activity.opacity(0.12), in: Capsule())
                            .foregroundStyle(DS.Color.activity)
                    }
                }
            }

            ForEach(suggestion.exercises) { exercise in
                SuggestedExerciseRow(
                    exercise: exercise,
                    onStart: { onStartExercise(exercise.definition) },
                    onAlternativeSelected: { alt in onStartExercise(alt) }
                )
            }
        }
    }

    private func restDaySection(suggestion: WorkoutSuggestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "bed.double.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Recovery Day")
                    .font(.subheadline.weight(.semibold))
            }

            Text(suggestion.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let next = suggestion.nextReadyMuscle {
                nextReadyLabel(muscle: next.muscle, date: next.readyDate)
            }

            if !suggestion.activeRecoverySuggestions.isEmpty {
                ActiveRecoveryCard(suggestions: suggestion.activeRecoverySuggestions)
            }
        }
    }

    private func nextReadyLabel(muscle: MuscleGroup, date: Date) -> some View {
        let hours = Swift.max(0, date.timeIntervalSince(Date()) / 3600)
        let timeText: String
        if hours < 1 {
            timeText = "soon"
        } else if hours < 24 {
            timeText = "in ~\(Int(hours))h"
        } else {
            let days = Int(hours / 24)
            timeText = "in ~\(days)d"
        }

        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(muscle.displayName) ready \(timeText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Colors

    private func recoveryColor(for muscle: MuscleGroup) -> Color {
        guard let state = fatigueByMuscle[muscle], state.lastTrainedDate != nil else {
            return .secondary.opacity(0.2)
        }
        let pct = state.recoveryPercent
        guard pct.isFinite else { return .secondary.opacity(0.2) }
        if pct >= 0.8 {
            return .green.opacity(0.35 + pct * 0.25)
        } else if pct >= 0.5 {
            return .yellow.opacity(0.35 + pct * 0.25)
        } else {
            return .red.opacity(0.3 + (1.0 - pct) * 0.3)
        }
    }

    private func recoveryStrokeColor(for muscle: MuscleGroup) -> Color {
        guard let state = fatigueByMuscle[muscle], state.lastTrainedDate != nil else {
            return .secondary.opacity(0.15)
        }
        let pct = state.recoveryPercent
        guard pct.isFinite else { return .secondary.opacity(0.15) }
        if pct >= 0.8 { return .green.opacity(0.4) }
        if pct >= 0.5 { return .yellow.opacity(0.4) }
        return .red.opacity(0.4)
    }
}
