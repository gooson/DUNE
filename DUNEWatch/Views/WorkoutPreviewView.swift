import SwiftUI
import WatchKit

/// Pre-workout confirmation screen showing exercise list and a prominent Start button.
/// Presented after selecting a template or quick-start exercise, before HKWorkoutSession begins.
struct WorkoutPreviewView: View {
    let snapshot: WorkoutSessionTemplate
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.dismiss) private var dismiss

    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Exercise list
            List {
                Section {
                    ForEach(Array(snapshot.entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.exerciseName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    Text("\(entry.defaultSets)×\(entry.defaultReps)")
                                    if let kg = entry.defaultWeightKg, kg > 0 {
                                        Text("· \(kg, specifier: "%.1f")kg")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(snapshot.entries.count) exercises")
                }
            }

            // Start button — fixed at bottom
            Button {
                startWorkout()
            } label: {
                HStack {
                    if isStarting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text("Start")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isStarting)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .navigationTitle(snapshot.name)
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startWorkout() {
        guard !isStarting else { return }
        isStarting = true

        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startQuickWorkout(with: snapshot)
                WKInterfaceDevice.current().play(.success)
                isStarting = false
            } catch {
                isStarting = false
                errorMessage = "Failed to start: \(error.localizedDescription)"
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
