import SwiftUI
import SwiftData

/// Main Watch screen: displays routines synced from iPhone via CloudKit + Quick Start.
struct RoutineListView: View {
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Environment(WorkoutManager.self) private var workoutManager

    @State private var errorMessage: String?

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                routineList
            }
        }
        .navigationTitle("Dailve")
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var routineList: some View {
        List {
            // Quick Start entry point
            Section {
                NavigationLink {
                    QuickStartPickerView()
                } label: {
                    Label("Quick Start", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            // Template list
            Section("Routines") {
                ForEach(templates) { template in
                    Button {
                        startWorkout(with: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(template.exerciseEntries.count) exercises")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Routines")
                .font(.headline)
            Text("Create a routine\non your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                QuickStartPickerView()
            } label: {
                Label("Quick Start", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top, 8)
        }
        .padding()
    }

    private func startWorkout(with template: WorkoutTemplate) {
        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startWorkout(with: template)
            } catch {
                errorMessage = "Failed to start: \(error.localizedDescription)"
            }
        }
    }
}
