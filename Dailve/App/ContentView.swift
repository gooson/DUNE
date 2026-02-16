import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab(AppSection.dashboard.title, systemImage: AppSection.dashboard.icon) {
                NavigationStack {
                    DashboardView()
                }
            }
            Tab(AppSection.exercise.title, systemImage: AppSection.exercise.icon) {
                NavigationStack {
                    ActivityView()
                }
            }
            Tab(AppSection.sleep.title, systemImage: AppSection.sleep.icon) {
                NavigationStack {
                    SleepView()
                }
            }
            Tab(AppSection.body.title, systemImage: AppSection.body.icon) {
                NavigationStack {
                    BodyCompositionView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
}
