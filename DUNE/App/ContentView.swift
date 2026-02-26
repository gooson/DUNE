import SwiftUI

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    @State private var selectedSection: AppSection = .today
    @State private var todayScrollToTopSignal = 0
    @State private var activityScrollToTopSignal = 0
    @State private var wellnessScrollToTopSignal = 0

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        self.sharedHealthDataService = sharedHealthDataService
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(AppSection.today.title, systemImage: AppSection.today.icon, value: AppSection.today) {
                NavigationStack {
                    DashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: todayScrollToTopSignal
                    )
                }
            }
            Tab(AppSection.train.title, systemImage: AppSection.train.icon, value: AppSection.train) {
                NavigationStack {
                    ActivityView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: activityScrollToTopSignal
                    )
                }
            }
            Tab(AppSection.wellness.title, systemImage: AppSection.wellness.icon, value: AppSection.wellness) {
                NavigationStack {
                    WellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: wellnessScrollToTopSignal
                    )
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private var tabSelection: Binding<AppSection> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                if selectedSection == newValue {
                    switch newValue {
                    case .today:
                        todayScrollToTopSignal += 1
                    case .train:
                        activityScrollToTopSignal += 1
                    case .wellness:
                        wellnessScrollToTopSignal += 1
                    }
                }
                selectedSection = newValue
            }
        )
    }
}

#Preview {
    ContentView()
}
