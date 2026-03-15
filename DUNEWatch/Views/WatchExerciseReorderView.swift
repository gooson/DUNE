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

                        VStack(spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.md) {
                                if isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.Color.positive)
                                        .frame(width: 20)
                                } else if isCurrent {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(DS.Color.activity)
                                        .frame(width: 20)
                                } else {
                                    Text("\(index + 1)")
                                        .font(DS.Typography.metricLabel)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                }

                                Text(entry.exerciseName)
                                    .font(DS.Typography.tileSubtitle)
                                    .lineLimit(1)
                            }
                            .opacity(isCompleted ? 0.5 : 1.0)

                            if !isCompleted {
                                HStack(spacing: DS.Spacing.sm) {
                                    Button {
                                        workoutManager.moveExercise(at: index, direction: .up)
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, minHeight: 28)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!workoutManager.canMoveExercise(at: index, direction: .up))

                                    Button {
                                        workoutManager.moveExercise(at: index, direction: .down)
                                    } label: {
                                        Image(systemName: "arrow.down")
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, minHeight: 28)
                                    }
                                    .buttonStyle(.bordered)
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
    }
}
