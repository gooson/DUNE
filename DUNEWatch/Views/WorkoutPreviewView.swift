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
                        HStack(spacing: DS.Spacing.md) {
                            Text("\(index + 1)")
                                .font(DS.Typography.metricLabel)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(entry.exerciseName)
                                    .font(DS.Typography.tileSubtitle)
                                    .lineLimit(1)

                                HStack(spacing: DS.Spacing.xs) {
                                    Text("\(entry.defaultSets)\u{00d7}\(entry.defaultReps)")
                                    if let kg = entry.defaultWeightKg, kg > 0 {
                                        Text("· \(kg, specifier: "%.1f")kg")
                                    }
                                }
                                .font(DS.Typography.metricLabel)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(snapshot.entries.count) exercises")
                }
            }
            .scrollContentBackground(.hidden)

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
            .tint(DS.Color.positive)
            .disabled(isStarting)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xs)
        }
        .background { WatchWaveBackground() }
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
