import SwiftUI
import SwiftData

@main
struct DUNEApp: App {
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @State private var showConsentSheet = false

    let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService

    private static var isRunningXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static var isRunningUITests: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitesting") || arguments.contains("--healthkit-permission-uitest")
    }

    private static var isRunningUnitTests: Bool {
        isRunningXCTest && !isRunningUITests
    }

    init() {
        self.sharedHealthDataService = SharedHealthDataServiceImpl(healthKitManager: .shared)
        let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(
            cloudKitDatabase: (cloudSyncEnabled && !Self.isRunningXCTest) ? .automatic : .none
        )
        do {
            modelContainer = try ModelContainer(
                for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self, InjuryRecord.self,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Schema migration failed — delete store and retry (MVP: no user data to preserve)
            AppLogger.data.error("ModelContainer failed: \(error)")
            Self.deleteStoreFiles(at: config.url)
            do {
                modelContainer = try ModelContainer(
                    for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self, InjuryRecord.self,
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
            Group {
                if Self.isRunningUnitTests {
                    Color.clear
                } else {
                    ContentView(sharedHealthDataService: sharedHealthDataService)
                        .onAppear {
                            if !hasShownConsent && !Self.isRunningXCTest {
                                showConsentSheet = true
                            }
                            // Skip WC activation during XCTest to reduce startup flakiness.
                            if !Self.isRunningXCTest {
                                WatchSessionManager.shared.activate()
                            }
                        }
                        .sheet(isPresented: $showConsentSheet) {
                            CloudSyncConsentView(isPresented: $showConsentSheet)
                        }
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
