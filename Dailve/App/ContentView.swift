import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab(AppSection.today.title, systemImage: AppSection.today.icon) {
                NavigationStack {
                    DashboardView()
                }
            }
            Tab(AppSection.train.title, systemImage: AppSection.train.icon) {
                NavigationStack {
                    ActivityView()
                }
            }
            Tab(AppSection.wellness.title, systemImage: AppSection.wellness.icon) {
                NavigationStack {
                    WellnessView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
}
