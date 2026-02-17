import SwiftUI
import SwiftData

@main
struct DailveApp: App {
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled = false
    @State private var showConsentSheet = false

    let modelContainer: ModelContainer

    init() {
        let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(
            cloudKitDatabase: cloudSyncEnabled ? .automatic : .none
        )
        do {
            modelContainer = try ModelContainer(
                for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Schema migration failed — delete store and retry (MVP: no user data to preserve)
            AppLogger.data.error("ModelContainer failed: \(error)")
            Self.deleteStoreFiles(at: config.url)
            do {
                modelContainer = try ModelContainer(
                    for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
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
        // SwiftData/SQLite uses .sqlite, .sqlite-wal, .sqlite-shm
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !hasShownConsent {
                        showConsentSheet = true
                    }
                    // Activate WatchConnectivity — syncs exercise library to Watch
                    WatchSessionManager.shared.activate()
                }
                .sheet(isPresented: $showConsentSheet) {
                    CloudSyncConsentView(isPresented: $showConsentSheet)
                }
        }
        .modelContainer(modelContainer)
    }
}
