import SwiftUI
import SwiftData

/// Main Watch screen: displays routines synced from iPhone via CloudKit + Quick Start.
struct RoutineListView: View {
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Environment(WorkoutManager.self) private var workoutManager

    @State private var errorMessage: String?
    @State private var isStartingWorkout = false

    private var connectivity: WatchConnectivityManager { .shared }

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                routineList
            }
        }
        .navigationTitle("Dailve")
        .overlay {
            if isStartingWorkout {
                startingOverlay
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Routine List

    private var routineList: some View {
        List {
            // Template list (primary content)
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
                    .disabled(isStartingWorkout)
                }
            }

            // Quick Start (secondary, at bottom)
            Section {
                NavigationLink(value: WatchRoute.quickStart) {
                    Label("Quick Start", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            // Sync status indicator
            Section {
                syncStatusView
            }
        }
    }

    // MARK: - Empty State

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

            NavigationLink(value: WatchRoute.quickStart) {
                Label("Quick Start", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top, 8)

            syncStatusView
                .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Sync Status

    private var syncStatusView: some View {
        HStack(spacing: 4) {
            switch connectivity.syncStatus {
            case .syncing:
                ProgressView()
                    .frame(width: 12, height: 12)
                Text("Syncing...")
            case .synced(let date):
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text(syncTimeLabel(from: date))
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                Text(message)
            case .notConnected:
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.secondary)
                Text("iPhone not connected")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func syncTimeLabel(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just synced"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) min ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }

    // MARK: - Starting Overlay

    private var startingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                ProgressView()
                Text("Starting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func startWorkout(with template: WorkoutTemplate) {
        guard !isStartingWorkout else { return }
        isStartingWorkout = true

        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startWorkout(with: template)
                WKInterfaceDevice.current().play(.success)
            } catch {
                isStartingWorkout = false
                errorMessage = "Failed to start: \(error.localizedDescription)"
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
