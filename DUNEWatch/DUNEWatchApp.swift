import SwiftUI
import SwiftData

@main
struct DUNEWatchApp: App {
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

    /// Theme synced from iPhone via WatchConnectivity.
    /// Falls back to desertWarm if never synced.
    private var resolvedTheme: AppTheme {
        AppTheme(rawValue: connectivity.syncedThemeRawValue) ?? .desertWarm
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivity)
                .environment(\.appTheme, resolvedTheme)
                .tint(resolvedTheme.accentColor)
                .onAppear {
                    connectivity.activate()
                }
        }
        .modelContainer(modelContainer)
    }
}
