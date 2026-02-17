import SwiftUI
import SwiftData

@main
struct DailveWatchApp: App {
    @State private var connectivity = WatchConnectivityManager.shared

    let modelContainer: ModelContainer

    init() {
        let config = ModelConfiguration(
            cloudKitDatabase: .automatic
        )
        do {
            modelContainer = try ModelContainer(
                for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
                    CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Schema migration failed — delete store and retry (MVP)
            Self.deleteStoreFiles(at: config.url)
            do {
                modelContainer = try ModelContainer(
                    for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
                        CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
                    migrationPlan: AppMigrationPlan.self,
                    configurations: config
                )
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivity)
                .onAppear {
                    connectivity.activate()
                }
        }
        .modelContainer(modelContainer)
    }
}
