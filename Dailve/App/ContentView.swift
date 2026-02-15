import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        TabView {
            Tab(AppSection.dashboard.title, systemImage: AppSection.dashboard.icon) {
                DashboardView()
            }
            Tab(AppSection.exercise.title, systemImage: AppSection.exercise.icon) {
                ActivityView()
            }
            Tab(AppSection.sleep.title, systemImage: AppSection.sleep.icon) {
                SleepView()
            }
            Tab(AppSection.body.title, systemImage: AppSection.body.icon) {
                BodyCompositionView()
            }
        }
    }

    // MARK: - iPad

    @State private var selectedSection: AppSection? = .dashboard

    private var iPadLayout: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .accessibilityIdentifier("sidebar-\(section.rawValue)")
            }
            .accessibilityIdentifier("sidebar-list")
            .navigationTitle("Dailve")
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView()
            case .exercise:
                ActivityView()
            case .sleep:
                SleepView()
            case .body:
                BodyCompositionView()
            case .none:
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "heart.text.clipboard",
                    description: Text("Choose a category from the sidebar.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
}
