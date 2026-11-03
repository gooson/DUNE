import SwiftUI

/// Popover/sheet showing detailed recovery info for a single muscle group.
/// When `isInline` is true, renders as an inline section (e.g., inside MuscleMapDetailView)
/// instead of a sheet presentation.
struct MuscleDetailPopover: View {
    let muscle: MuscleGroup
    let fatigueState: MuscleFatigueState?
    let library: ExerciseLibraryQuerying
    var isInline: Bool = false

    @State private var showingInfoSheet = false
    @State private var topExercises: [ExerciseDefinition] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title3) private var headerIconSize: CGFloat = 32

    var body: some View {
        content
            .task(id: muscle) {
                topExercises = Array(
                    library.exercises(forMuscle: muscle)
                        .filter { $0.category == .strength || $0.category == .bodyweight }
                        .prefix(3)
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if isInline {
            inlineBody
                .padding(DS.Spacing.lg)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        } else {
            ScrollView {
                inlineBody
                    .padding(DS.Spacing.xl)
            }
            .accessibilityIdentifier("activity-muscle-detail-scroll")
            .background { SheetWaveBackground().opacity(0.55) }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: isInline ? DS.Spacing.md : DS.Spacing.lg) {
            header

            // Stats grid
            if let state = fatigueState {
                statsGrid(state: state)
            }
            if let score = fatigueState?.compoundScore {
                Button {
                    showingInfoSheet = true
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("View Calculation")
                            .font(.caption)
                    }
                    .foregroundStyle(DS.Color.activity)
                }
                .accessibilityIdentifier("activity-muscle-detail-calculation")
                .sheet(isPresented: $showingInfoSheet) {
                    FatigueInfoSheet(score: score)
                }
            } else if isInline && fatigueState == nil {
                Text("No recent activity for this muscle")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            // Recommended exercises
            if !topExercises.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Exercises")
                        .font(.subheadline.weight(.semibold))

                    ForEach(topExercises) { (exercise: ExerciseDefinition) in
                        exerciseRow(exercise)
                    }
                }
            }
        }
    }

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    private var header: some View {
        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return headerLayout {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: muscle.iconName)
                    .font(.title3)
                    .foregroundStyle(palette.heroAccent)
                    .frame(minWidth: headerIconSize, minHeight: headerIconSize)
                    .accessibilityHidden(true)
                muscleTitle
                    .foregroundStyle(palette.ink)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: DS.Spacing.xs) }
            recoveryBadge
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var muscleTitle: some View {
        let title = Text(muscle.displayName)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        if isInline {
            title
        } else {
            title.accessibilityIdentifier("activity-muscle-detail-popover-sheet")
        }
    }

    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            exercise.equipment.svgIcon(size: 16)
                .foregroundStyle(DS.Color.activity)
                .frame(minWidth: 32, minHeight: 32)
                .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text(exercise.localizedName)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Recovery Badge

    private var recoveryBadge: some View {
        let level = fatigueState?.fatigueLevel ?? .noData
        let color = level.color(for: colorScheme)
        return HStack(spacing: DS.Spacing.xxs) {
            Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(level.shortLabel)
                .font(.caption2.weight(.bold).monospacedDigit())
            Text(level.displayName)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(palette.ink.opacity(0.12), in: Capsule())
        .foregroundStyle(palette.ink)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("activity-muscle-detail-status")
    }

    // MARK: - Stats Grid

    private func statsGrid(state: MuscleFatigueState) -> some View {
        let columns = Array(repeating: GridItem(.flexible()),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)

        return LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
            statItem(
                title: "Fatigue Level",
                value: "\(state.fatigueLevel.shortLabel) / L10",
                icon: "flame.fill", id: "fatigue"
            )
            statItem(
                title: "Weekly Volume",
                value: "\(state.weeklyVolume.formattedWithSeparator) sets",
                icon: "chart.bar.fill", id: "weekly-volume"
            )
            statItem(
                title: "Last Trained",
                value: lastTrainedText(state: state),
                icon: "clock.fill", id: "last-trained"
            )
            if let score = state.compoundScore {
                statItem(
                    title: "Sleep Modifier",
                    value: "\(score.breakdown.sleepModifier.formattedWithSeparator(fractionDigits: 2))×",
                    icon: "moon.fill", id: "sleep-modifier"
                )
            } else {
                statItem(
                    title: "Base Recovery",
                    value: "\(Int(muscle.recoveryHours).formattedWithSeparator)h",
                    icon: "timer", id: "base-recovery"
                )
            }
        }
    }

    private func statItem(title: LocalizedStringKey, value: String, icon: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.activity)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity-muscle-detail-value-\(id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func lastTrainedText(state: MuscleFatigueState) -> String {
        guard let hours = state.hoursSinceLastTrained, hours.isFinite else { return String(localized: "Never") }
        if hours < 1 { return String(localized: "Just now") }
        if hours < 24 { return String(localized: "\(Int(hours).formattedWithSeparator)h ago") }
        let days = Int(hours / 24)
        return String(localized: "\(days.formattedWithSeparator)d ago")
    }
}
