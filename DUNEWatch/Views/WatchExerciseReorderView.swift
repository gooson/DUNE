import SwiftUI

/// In-session exercise reorder sheet for Watch.
/// Shows exercise list with context menu for Move Up/Move Down.
/// Completed exercises are pinned and cannot be moved.
struct WatchExerciseReorderView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let snapshot = workoutManager.templateSnapshot {
                Section {
                    ForEach(Array(snapshot.entries.enumerated()), id: \.element.id) { index, entry in
                        let isCompleted = index < workoutManager.completedSetsData.count
                            && !workoutManager.completedSetsData[index].isEmpty
                        let isCurrent = index == workoutManager.currentExerciseIndex

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
                        .contextMenu {
                            if !isCompleted {
                                if workoutManager.canMoveExercise(at: index, direction: .up) {
                                    Button {
                                        workoutManager.moveExercise(at: index, direction: .up)
                                    } label: {
                                        Label(String(localized: "Move Up"), systemImage: "arrow.up")
                                    }
                                }
                                if workoutManager.canMoveExercise(at: index, direction: .down) {
                                    Button {
                                        workoutManager.moveExercise(at: index, direction: .down)
                                    } label: {
                                        Label(String(localized: "Move Down"), systemImage: "arrow.down")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Reorder Exercises"))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { WatchWaveBackground() }
        .navigationTitle(String(localized: "Reorder"))
    }
}
