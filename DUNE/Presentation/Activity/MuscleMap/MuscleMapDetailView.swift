import SwiftUI

/// Detail view for the Muscle Map — combines recovery status and volume analysis.
/// Push-navigated from Activity tab when tapping the muscle map area.
struct MuscleMapDetailView: View {
    let fatigueStates: [MuscleFatigueState]

    @State private var viewModel = MuscleMapDetailViewModel()

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Muscle map (expanded)
                MuscleRecoveryMapView(
                    fatigueStates: fatigueStates,
                    isExpanded: true,
                    onMuscleSelected: { muscle in
                        withAnimation(DS.Animation.snappy) {
                            viewModel.selectedMuscle = viewModel.selectedMuscle == muscle ? nil : muscle
                        }
                    }
                )

                // Selected muscle inline detail
                if let muscle = viewModel.selectedMuscle {
                    MuscleInlineDetailSection(
                        muscle: muscle,
                        fatigueState: viewModel.fatigueByMuscle[muscle],
                        library: library
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
                                set: { viewModel.weeklySetGoal = $0 }
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

                // Recovery Overview
                SectionGroup(title: "Recovery Status", icon: "heart.text.clipboard", iconColor: DS.Color.activity) {
                    RecoveryOverviewSection(
                        fatigueStates: fatigueStates,
                        recoveredCount: viewModel.recoveredCount,
                        overworkedMuscles: viewModel.overworkedMuscles,
                        nextRecovery: viewModel.nextRecovery
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Muscle Map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadData(fatigueStates: fatigueStates)
        }
    }
}
