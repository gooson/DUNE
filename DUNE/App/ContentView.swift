import SwiftUI

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        self.sharedHealthDataService = sharedHealthDataService
    }

    var body: some View {
        TabView {
            Tab(AppSection.today.title, systemImage: AppSection.today.icon) {
                NavigationStack {
                    DashboardView(sharedHealthDataService: sharedHealthDataService)
                }
                .environment(\.wavePreset, .today)
                .environment(\.waveColor, DS.Color.warmGlow)
            }
            Tab(AppSection.train.title, systemImage: AppSection.train.icon) {
                NavigationStack {
                    ActivityView(sharedHealthDataService: sharedHealthDataService)
                }
                .environment(\.wavePreset, .train)
                .environment(\.waveColor, DS.Color.tabTrain)
            }
            Tab(AppSection.wellness.title, systemImage: AppSection.wellness.icon) {
                NavigationStack {
                    WellnessView(sharedHealthDataService: sharedHealthDataService)
                }
                .environment(\.wavePreset, .wellness)
                .environment(\.waveColor, DS.Color.tabWellness)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
}
