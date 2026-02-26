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
                    targetMuscleSection
                    equipmentInfoSection
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
            Image(systemName: exercise.resolvedActivityType.iconName)
                .font(.system(size: 40))
                .foregroundStyle(exercise.resolvedActivityType.color)
                .frame(width: 64, height: 64)
                .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.localizedName)
                    .font(.title3.weight(.semibold))
                Text(exercise.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: DS.Spacing.sm) {
                    Label(exercise.category.displayName, systemImage: categoryIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(exercise.equipment.localizedDisplayName, systemImage: exercise.equipment.iconName)
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

    // MARK: - Target Muscle Map

    @ViewBuilder
    private var targetMuscleSection: some View {
        if !exercise.primaryMuscles.isEmpty || !exercise.secondaryMuscles.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("타겟 근육")
                    .font(.headline)
                ExerciseMuscleMapView(
                    primaryMuscles: exercise.primaryMuscles,
                    secondaryMuscles: exercise.secondaryMuscles
                )

                // Legend
                HStack(spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Color.activity.opacity(0.7))
                            .frame(width: 12, height: 12)
                        Text("주동근")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Color.activity.opacity(0.25))
                            .frame(width: 12, height: 12)
                        Text("보조근")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("주동근은 동작의 핵심 자극 부위이고, 보조근은 함께 보조적으로 활성화되는 부위입니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Equipment Info

    private var equipmentInfoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("사용 기구")
                .font(.headline)
            HStack(spacing: DS.Spacing.md) {
                Image(exercise.equipment.svgAssetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(DS.Color.activity)
                    .frame(width: 80, height: 80)
                    .padding(DS.Spacing.sm)
                    .background(DS.Color.activity.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.equipment.localizedDisplayName)
                            .font(.subheadline.weight(.medium))
                        Text(exercise.equipment.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(exercise.equipment.equipmentDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                infoItem(label: "MET", value: exercise.metValue.formattedWithSeparator(fractionDigits: 1))
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
