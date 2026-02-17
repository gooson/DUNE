import SwiftUI

struct ExerciseDetailSheet: View {
    let exercise: ExerciseDefinition
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection
                    descriptionSection
                    formCuesSection
                    muscleSection
                    infoSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
            .navigationTitle(exercise.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        dismiss()
                        onSelect()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: WorkoutSummary.iconName(for: exercise.name))
                .font(.system(size: 40))
                .foregroundStyle(DS.Color.activity)
                .frame(width: 64, height: 64)
                .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.name)
                    .font(.title3.weight(.semibold))
                HStack(spacing: DS.Spacing.sm) {
                    Label(exercise.category.displayName, systemImage: categoryIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(exercise.equipment.displayName, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    private var categoryIcon: String {
        switch exercise.category {
        case .strength: "figure.strengthtraining.traditional"
        case .cardio: "figure.run"
        case .hiit: "bolt.fill"
        case .flexibility: "figure.flexibility"
        case .bodyweight: "figure.core.training"
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        if let desc = exercise.description ?? ExerciseDescriptions.description(for: exercise.id) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("About")
                    .font(.headline)
                Text(desc)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Form Cues

    @ViewBuilder
    private var formCuesSection: some View {
        let cues = ExerciseDescriptions.formCues(for: exercise.id)
        if !cues.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Form Cues")
                    .font(.headline)
                ForEach(Array(cues.enumerated()), id: \.offset) { index, cue in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(DS.Color.activity, in: Circle())
                        Text(cue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Muscles

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Muscles")
                .font(.headline)

            if !exercise.primaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Primary")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: DS.Spacing.xs) {
                        ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.activity.opacity(0.15), in: Capsule())
                                .foregroundStyle(DS.Color.activity)
                        }
                    }
                }
            }

            if !exercise.secondaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Secondary")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: DS.Spacing.xs) {
                        ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Details")
                .font(.headline)

            HStack(spacing: DS.Spacing.lg) {
                infoItem(label: "Input", value: inputTypeLabel)
                infoItem(label: "MET", value: String(format: "%.1f", exercise.metValue))
            }
        }
    }

    private func infoItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private var inputTypeLabel: String {
        switch exercise.inputType {
        case .setsRepsWeight: "Weight + Reps"
        case .setsReps: "Reps Only"
        case .durationDistance: "Duration + Distance"
        case .durationIntensity: "Duration + Intensity"
        case .roundsBased: "Rounds"
        }
    }
}

// MARK: - Flow Layout

/// Simple horizontal wrapping layout for tags/chips.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
