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
            }
            Tab(AppSection.train.title, systemImage: AppSection.train.icon) {
                NavigationStack {
                    ActivityView(sharedHealthDataService: sharedHealthDataService)
                }
            }
            Tab(AppSection.wellness.title, systemImage: AppSection.wellness.icon) {
                NavigationStack {
                    WellnessView(sharedHealthDataService: sharedHealthDataService)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
}
