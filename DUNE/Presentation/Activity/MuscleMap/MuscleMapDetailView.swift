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

    init(fatigueStates: [MuscleFatigueState], library: ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.fatigueStates = fatigueStates
        self.library = library
    }

    var body: some View {
        AdaptivePaneView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                // Muscle map (expanded)
                MuscleRecoveryMapView(
                    fatigueStates: fatigueStates,
                    isExpanded: true,
                    onMuscleSelected: { muscle in
                        withAnimation(reduceMotion ? nil : DS.Animation.snappy) {
                            viewModel.selectedMuscle = viewModel.selectedMuscle == muscle ? nil : muscle
                        }
                        selected3DMuscle = muscle
                        if sizeClass != .regular { showing3DMap = true }
                    }
                )

                    Button {
                        showing3DMap = true
                    } label: {
                        Label("3D Muscle Map", systemImage: "cube")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(DS.Spacing.lg)
            }
        } secondary: {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                // Selected muscle inline detail
                if let muscle = viewModel.selectedMuscle {
                    MuscleDetailPopover(
                        muscle: muscle,
                        fatigueState: viewModel.fatigueByMuscle[muscle],
                        library: library,
                        isInline: true
                    )
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
