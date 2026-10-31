import SwiftUI

/// Detail view for the Muscle Map — combines recovery status and volume analysis.
/// Push-navigated from Activity tab when tapping the muscle map area.
struct MuscleMapDetailView: View {
    let fatigueStates: [MuscleFatigueState]
    let library: ExerciseLibraryQuerying

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = MuscleMapDetailViewModel()
    @State private var showing3DMap = false
    @State private var selected3DMuscle: MuscleGroup?

    // Temporary A04 availability gate; retain the 3D destination for a later release.
    private let is3DMuscleMapEntryAvailable = false

    init(fatigueStates: [MuscleFatigueState], library: ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.fatigueStates = fatigueStates
        self.library = library
    }

    var body: some View {
        AdaptivePaneView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    A03MuscleMapHeader(
                        recoveredCount: viewModel.recoveredCount,
                        observedCount: fatigueStates.count,
                        isLoaded: fatigueStates.isEmpty || !viewModel.fatigueByMuscle.isEmpty
                    )

                    // Preserve the real front/back SVG, mode selector, info sheets and legends.
                    StandardCard(padding: DS.Spacing.md) {
                        MuscleRecoveryMapView(
                            fatigueStates: fatigueStates,
                            isExpanded: true,
                            onMuscleSelected: { muscle in
                                withAnimation(reduceMotion ? nil : DS.Animation.snappy) {
                                    viewModel.selectedMuscle = viewModel.selectedMuscle == muscle ? nil : muscle
                                }
                                selected3DMuscle = muscle
                                if is3DMuscleMapEntryAvailable && sizeClass != .regular { showing3DMap = true }
                            }
                        )
                    }

                    Button {
                        showing3DMap = true
                    } label: {
                        Label("3D Muscle Map", systemImage: "cube")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!is3DMuscleMapEntryAvailable)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        } secondary: {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Selected muscle inline detail
                if let muscle = viewModel.selectedMuscle {
                    MuscleDetailPopover(
                        muscle: muscle,
                        fatigueState: viewModel.fatigueByMuscle[muscle],
                        library: library,
                        isInline: true
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("musclemap-detail-selected-muscle")
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Color.activity.opacity(0.45), lineWidth: 1)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Volume Analysis
                SectionGroup(title: "Volume Analysis", icon: "chart.bar.fill", iconColor: DS.Color.activity) {
                    if viewModel.totalWeeklySets > 0 {
                        VolumeBreakdownSection(
                            sortedMuscleVolumes: viewModel.sortedMuscleVolumes,
                            totalWeeklySets: viewModel.totalWeeklySets,
                            trainedCount: viewModel.trainedCount,
                            balanceInfo: viewModel.balanceInfo,
                            weeklySetGoal: Binding(
                                get: { viewModel.weeklySetGoal },
                                set: { viewModel.setWeeklySetGoal($0) }
                            )
                        )
                    } else {
                        ContentUnavailableView(
                            "No Volume Data",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Start recording workouts to see muscle volume analysis.")
                        )
                    }
                }
                .accessibilityIdentifier("musclemap-detail-volume-section")

                // Recovery Overview
                SectionGroup(title: "Recovery Status", icon: "heart.text.clipboard", iconColor: DS.Color.activity) {
                    RecoveryOverviewSection(
                        fatigueStates: fatigueStates,
                        recoveredCount: viewModel.recoveredCount,
                        overworkedMuscles: viewModel.overworkedMuscles,
                        nextRecovery: viewModel.nextRecovery
                    )
                }
                .accessibilityIdentifier("musclemap-detail-recovery-section")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("activity-musclemap-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Muscle Map")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showing3DMap) {
            MuscleMap3DView(
                fatigueStates: fatigueStates,
                highlightedMuscle: selected3DMuscle
            )
        }
        .task {
            viewModel.loadData(fatigueStates: fatigueStates)
        }
    }
}

/// A03's local recovery summary uses only the observed states and existing VM count.
private struct A03MuscleMapHeader: View {
    let recoveredCount: Int
    let observedCount: Int
    let isLoaded: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: 44, height: 44)
                .background(palette.ink.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Recovery Status")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.muted)
                    .accessibilityAddTraits(.isHeader)
                if observedCount == 0 {
                    Text("Start training to track recovery")
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isLoaded {
                    Text("\(recoveredCount.formatted())/\(observedCount.formatted()) muscles ready")
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView()
                        .tint(palette.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("musclemap-detail-header")
    }
}
