import SwiftUI

/// Shown when a workout is active (received from iPhone).
/// Displays current set info and allows set completion with Digital Crown input.
struct WorkoutActiveView: View {
    let workout: WatchWorkoutState
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var isCompleted = false
    @State private var heartRate: Double = 0
    @State private var heartRateTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Exercise name and set counter
                exerciseHeader

                Divider()

                // Input fields
                setInputSection

                // Complete button
                completeButton

                // Heart rate display
                heartRateDisplay
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(workout.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            weight = workout.targetWeight ?? 0
            reps = workout.targetReps ?? 0
            startHeartRateMonitoring()
        }
        .onDisappear {
            heartRateTask?.cancel()
            heartRateTask = nil
        }
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(spacing: 4) {
            Text("Set \(workout.currentSet) of \(workout.totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Progress indicator
            HStack(spacing: 3) {
                ForEach(1...max(workout.totalSets, 1), id: \.self) { set in
                    Circle()
                        .fill(set < workout.currentSet ? .green : (set == workout.currentSet ? .green.opacity(0.5) : .gray.opacity(0.3)))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Input

    private var setInputSection: some View {
        VStack(spacing: 8) {
            if workout.targetWeight != nil {
                // Weight input with Digital Crown
                HStack {
                    Text("Weight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(weight, specifier: "%.1f") kg")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.green)
                }
                .focusable()
                .digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)
            }

            if workout.targetReps != nil {
                // Reps input
                HStack {
                    Text("Reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            if reps > 0 { reps -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Text("\(reps)")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(minWidth: 24)

                        Button {
                            if reps < 100 { reps += 1 }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            completeSet()
        } label: {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                Text(isCompleted ? "Done" : "Complete Set")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isCompleted ? .gray : .green)
        .disabled(isCompleted)
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.red)

            if heartRate > 0 {
                Text("\(Int(heartRate)) bpm")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func completeSet() {
        isCompleted = true

        let setData = WatchSetData(
            setNumber: workout.currentSet,
            weight: weight > 0 ? weight : nil,
            reps: reps > 0 ? reps : nil,
            duration: nil,
            isCompleted: true
        )

        connectivity.sendSetCompletion(
            setData,
            exerciseID: workout.exerciseID,
            exerciseName: workout.exerciseName
        )
    }

    private func startHeartRateMonitoring() {
        heartRateTask?.cancel()
        heartRateTask = Task {
            // Heart rate monitoring via HealthKit would go here.
            // For now, placeholder that simulates receiving HR updates.
            // In production: use HKHealthStore + HKLiveWorkoutBuilder
        }
    }
}
