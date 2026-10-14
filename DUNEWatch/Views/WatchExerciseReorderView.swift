import SwiftUI

/// In-session exercise reorder sheet for Watch.
/// Shows exercise list with explicit up/down buttons.
/// Completed exercises are pinned and cannot be moved.
struct WatchExerciseReorderView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        List {
            if let snapshot = workoutManager.templateSnapshot {
                Section {
                    ForEach(Array(snapshot.entries.enumerated()), id: \.element.id) { index, entry in
                        let isCompleted = index < workoutManager.completedSetsData.count
                            && !workoutManager.completedSetsData[index].isEmpty
                        let isCurrent = index == workoutManager.currentExerciseIndex

                        VStack(spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.md) {
                                EquipmentIconView(equipment: entry.equipment, size: 20)
                                    .frame(width: 24, height: 24)
                                    .accessibilityHidden(true)

                                if isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.Color.positive)
                                        .frame(width: 18)
                                } else if isCurrent {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(DS.Color.activity)
                                        .frame(width: 18)
                                } else {
                                    Text("\(index + 1)")
                                        .font(DS.Typography.metricLabel)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                }

                                Text(entry.exerciseName)
                                    .font(DS.Typography.tileTitle)
                                    .lineLimit(2)
                            }
                            .opacity(isCompleted ? 0.5 : 1.0)

                            if !isCompleted {
                                HStack(spacing: DS.Spacing.sm) {
                                    Button {
                                        workoutManager.moveExercise(at: index, direction: .up)
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Move Up")
                                    .accessibilityIdentifier("watch-reorder-up-\(index)")
                                    .disabled(!workoutManager.canMoveExercise(at: index, direction: .up))

                                    Button {
                                        workoutManager.moveExercise(at: index, direction: .down)
                                    } label: {
                                        Image(systemName: "arrow.down")
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Move Down")
                                    .accessibilityIdentifier("watch-reorder-down-\(index)")
                                    .disabled(!workoutManager.canMoveExercise(at: index, direction: .down))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Reorder Exercises")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { WatchWaveBackground() }
        .accessibilityIdentifier("watch-exercise-reorder-screen")
    }
}
