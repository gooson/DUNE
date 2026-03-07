import SwiftUI

/// visionOS main navigation view.
/// Uses standard TabView which renders as a left-side vertical tab bar on visionOS.
/// Glass material is applied automatically by the system.
struct VisionContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var selectedSection: AppSection = .today
    @State private var refreshSignal = 0
    @State private var foregroundTask: Task<Void, Never>?

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab(value: AppSection.today) {
                NavigationStack {
                    VisionDashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        refreshSignal: refreshSignal,
                        onOpen3DCharts: {
                            guard supportsMultipleWindows else { return }
                            openWindow(id: "chart3d")
                        },
                        onOpenVolumetric: {
                            guard supportsMultipleWindows else { return }
                            openWindow(id: "spatial-volume")
                        }
                    )
                }
            } label: {
                Label {
                    Text(verbatim: AppSection.today.title)
                } icon: {
                    Image(systemName: AppSection.today.icon)
                }
            }
            Tab(value: AppSection.train) {
                NavigationStack {
                    VisionTrainView(
                        onOpen3DCharts: {
                            guard supportsMultipleWindows else { return }
                            openWindow(id: "chart3d")
                        }
                    )
                }
            } label: {
                Label {
                    Text(verbatim: AppSection.train.title)
                } icon: {
                    Image(systemName: AppSection.train.icon)
                }
            }
            Tab(value: AppSection.wellness) {
                NavigationStack {
                    VisionPlaceholderView(
                        title: AppSection.wellness.title,
                        systemImage: AppSection.wellness.icon,
                        message: "Wellness detail surfaces will be added after the shared visionOS source set is stabilized."
                    )
                }
            } label: {
                Label {
                    Text(verbatim: AppSection.wellness.title)
                } icon: {
                    Image(systemName: AppSection.wellness.icon)
                }
            }
            Tab(value: AppSection.life) {
                NavigationStack {
                    VisionPlaceholderView(
                        title: AppSection.life.title,
                        systemImage: AppSection.life.icon,
                        message: "Life tracking on visionOS is planned for a later phase."
                    )
                }
            } label: {
                Label {
                    Text(verbatim: AppSection.life.title)
                } icon: {
                    Image(systemName: AppSection.life.icon)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase == .active {
                foregroundTask?.cancel()
                foregroundTask = Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
                }
            }
        }
        .task {
            guard let coordinator = refreshCoordinator else { return }
            for await _ in coordinator.refreshNeededStream {
                refreshSignal += 1
            }
        }
    }
}

private struct VisionPlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .navigationTitle(title)
    }
}
