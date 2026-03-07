import SwiftUI

struct VisionExerciseFormGuideView: View {
    @State private var viewModel: VisionExerciseFormGuideViewModel

    init(viewModel: VisionExerciseFormGuideViewModel = VisionExerciseFormGuideViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerCard

            switch viewModel.loadState {
            case .idle:
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)

            case .empty(let message):
                emptyState(message)

            case .ready:
                searchField

                if let message = viewModel.emptySearchMessage {
                    emptyState(message)
                }

                guideRail

                if let guide = viewModel.selectedGuide {
                    guideDetail(for: guide)
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercise Form Guide")
                .font(.title2.weight(.semibold))

            Text("Search a supported lift and inspect setup cues, target muscles, and equipment context before you move into the spatial strength scene.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 760, alignment: .leading)
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "Search",
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                )
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var guideRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(viewModel.visibleGuides) { guide in
                    Button {
                        viewModel.selectGuide(id: guide.id)
                    } label: {
                        guideCard(guide)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func guideCard(_ guide: VisionExerciseGuide) -> some View {
        let isSelected = guide.id == viewModel.selectedGuide?.id

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: guide.primaryDisplayName())
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let secondaryName = guide.secondaryDisplayName() {
                        Text(verbatim: secondaryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: guide.exercise.equipment.iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }

            HStack(spacing: 10) {
                chip(guide.difficultyLabel)
                chip(guide.primaryMuscleLabel)
            }
        }
        .frame(width: 240, alignment: .leading)
        .padding(18)
        .background(
            isSelected ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func chip(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }

    private func guideDetail(for guide: VisionExerciseGuide) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VisionExerciseMuscleMapView(
                primaryMuscles: guide.exercise.primaryMuscles,
                secondaryMuscles: guide.exercise.secondaryMuscles
            )
            .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 18) {
                guideDetailsHeader(guide)
                aboutSection(guide)
                formCueSection(guide)
                targetMuscleSection(guide)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guideDetailsHeader(_ guide: VisionExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: guide.primaryDisplayName())
                    .font(.title3.weight(.semibold))
                if let secondaryName = guide.secondaryDisplayName() {
                    Text(verbatim: secondaryName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                detailPill(title: "Difficulty", value: guide.difficultyLabel, icon: "chart.bar.doc.horizontal")
                detailPill(title: "Equipment", value: guide.exercise.equipment.displayName, icon: guide.exercise.equipment.iconName)
                detailPill(title: "Input", value: guide.inputTypeLabel, icon: "slider.horizontal.3")
            }

            Text(guide.exercise.equipment.equipmentDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func detailPill(title: LocalizedStringKey, value: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func aboutSection(_ guide: VisionExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Text(String(localized: String.LocalizationValue(guide.descriptionKey)))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func formCueSection(_ guide: VisionExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Form Cues")
                .font(.headline)

            ForEach(Array(guide.formCueKeys.enumerated()), id: \.offset) { index, cue in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.tint, in: Circle())

                    Text(String(localized: String.LocalizationValue(cue)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func targetMuscleSection(_ guide: VisionExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Target Muscles")
                .font(.headline)

            muscleRow(
                title: "Primary",
                muscles: guide.exercise.primaryMuscles
            )

            if !guide.exercise.secondaryMuscles.isEmpty {
                muscleRow(
                    title: "Secondary",
                    muscles: guide.exercise.secondaryMuscles
                )
            }

            Text("Primary muscles are the main targets of the movement. Secondary muscles assist and are activated alongside.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func muscleRow(title: LocalizedStringKey, muscles: [MuscleGroup]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(muscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private extension VisionExerciseGuide {
    var difficultyLabel: String {
        switch exercise.difficulty {
        case "advanced":
            String(localized: "Advanced")
        case "intermediate":
            String(localized: "Intermediate")
        default:
            String(localized: "Beginner")
        }
    }

    var primaryMuscleLabel: String {
        exercise.primaryMuscles.first?.displayName ?? String(localized: "Primary")
    }

    var inputTypeLabel: String {
        switch exercise.inputType {
        case .setsRepsWeight:
            String(localized: "Weight + Reps")
        case .setsReps:
            String(localized: "Reps Only")
        case .durationDistance:
            String(localized: "Duration + Distance")
        case .durationIntensity:
            String(localized: "Duration + Intensity")
        case .roundsBased:
            String(localized: "Rounds")
        }
    }
}
