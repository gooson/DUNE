import SwiftUI

/// Quick start workout from Watch using synced exercise library.
struct QuickStartView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity
    @State private var selectedExercise: WatchExerciseInfo?

    var body: some View {
        List(connectivity.exerciseLibrary, id: \.id) { exercise in
            Button {
                selectedExercise = exercise
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.caption)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if let reps = exercise.defaultReps {
                            Text("\(exercise.defaultSets)x\(reps)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(exercise.defaultSets) sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Quick Start")
        .sheet(item: $selectedExercise) { exercise in
            QuickWorkoutView(exercise: exercise)
        }
    }
}

extension WatchExerciseInfo: Identifiable {}

/// Minimal standalone workout view for Watch (without iPhone connection).
struct QuickWorkoutView: View {
    let exercise: WatchExerciseInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var currentSet = 1
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var completedSets: [WatchSetData] = []
    @State private var startTime = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(exercise.name)
                    .font(.caption.weight(.semibold))

                Text("Set \(currentSet) / \(exercise.defaultSets)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Weight input
                HStack {
                    Text("Weight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(weight, specifier: "%.1f") kg")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.green)
                }
                .focusable()
                .digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)

                // Reps input
                if exercise.defaultReps != nil {
                    HStack {
                        Text("Reps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Button { if reps > 0 { reps -= 1 } } label: {
                                Image(systemName: "minus.circle").font(.caption)
                            }
                            .buttonStyle(.plain)
                            Text("\(reps)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.green)
                                .frame(minWidth: 20)
                            Button { if reps < 100 { reps += 1 } } label: {
                                Image(systemName: "plus.circle").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    completeSet()
                } label: {
                    Label("Complete Set", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                if !completedSets.isEmpty {
                    Button {
                        finishWorkout()
                    } label: {
                        Label("Finish", systemImage: "flag.checkered")
                            .font(.caption2.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            reps = exercise.defaultReps ?? 0
        }
    }

    private func completeSet() {
        let setData = WatchSetData(
            setNumber: currentSet,
            weight: weight > 0 ? weight : nil,
            reps: reps > 0 ? reps : nil,
            duration: nil,
            isCompleted: true
        )
        completedSets.append(setData)

        // Send real-time update to iPhone if reachable
        connectivity.sendSetCompletion(
            setData,
            exerciseID: exercise.id,
            exerciseName: exercise.name
        )

        if currentSet < exercise.defaultSets {
            currentSet += 1
        }
    }

    private func finishWorkout() {
        let update = WatchWorkoutUpdate(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            completedSets: completedSets,
            startTime: startTime,
            endTime: Date(),
            heartRateSamples: []
        )
        connectivity.sendWorkoutCompletion(update)
        dismiss()
    }
}
