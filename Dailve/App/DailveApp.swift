import SwiftUI
import SwiftData

@main
struct DailveApp: App {
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @State private var showConsentSheet = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !hasShownConsent {
                        showConsentSheet = true
                    }
                }
                .sheet(isPresented: $showConsentSheet) {
                    CloudSyncConsentView(isPresented: $showConsentSheet)
                }
        }
        .modelContainer(for: [
            BodyCompositionRecord.self,
            ExerciseRecord.self
        ], isAutosaveEnabled: true)
    }
}
