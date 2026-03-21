import SwiftUI
import SwiftData

struct VisionSettingsView: View {
    private static let windowPlacementSmokeInitialDelayNanos: UInt64 = 1_000_000_000
    private static let windowPlacementSmokeStepDelayNanos: UInt64 = 350_000_000

    @AppStorage(SimulatorAdvancedMockDataModeStore.storageKey) private var isSimulatorMockEnabled = false

    private let modelContainer: ModelContainer
    private let smokeConfiguration: VisionWindowPlacementSmokeConfiguration

    @Environment(\.openWindow) private var openWindow

    @State private var isProcessingSimulatorMockData = false
    @State private var simulatorMockStatusMessage: String?

    init(
        modelContainer: ModelContainer,
        smokeConfiguration: VisionWindowPlacementSmokeConfiguration = .current()
    ) {
        self.modelContainer = modelContainer
        self.smokeConfiguration = smokeConfiguration
    }

    var body: some View {
        Form {
            if SimulatorAdvancedMockDataModeStore.isSimulatorAvailable {
                simulatorMockDataSection
            }
            aboutSection
        }
        .navigationTitle("Settings")
        .task(id: smokeConfiguration) {
            await runWindowPlacementSmokeContinuationIfNeeded()
        }
    }

    private var simulatorMockDataSection: some View {
        Section {
            HStack {
                Text("Preset")
                Spacer()
                Text("Advanced Athlete")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Status")
                Spacer()
                Text(isSimulatorMockEnabled ? "Enabled" : "Disabled")
                    .foregroundStyle(isSimulatorMockEnabled ? Color.accentColor : .secondary)
            }

            Button {
                seedAdvancedMockData()
            } label: {
                Label("Seed Advanced Mock Data", systemImage: "shippingbox.fill")
            }
            .accessibilityIdentifier("vision-settings-button-seed-advanced-mock-data")
            .disabled(isProcessingSimulatorMockData)

            Button(role: .destructive) {
                resetAdvancedMockData()
            } label: {
                Label("Reset Mock Data", systemImage: "trash")
            }
            .accessibilityIdentifier("vision-settings-button-reset-mock-data")
            .disabled(isProcessingSimulatorMockData || !isSimulatorMockEnabled)
        } header: {
            Text("Mock Data")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Simulator only. Seeds advanced athlete health trends, workouts, and per-exercise history.")
                if let simulatorMockStatusMessage {
                    Text(verbatim: simulatorMockStatusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    private func seedAdvancedMockData() {
        guard SimulatorAdvancedMockDataModeStore.isSimulatorAvailable else { return }
        guard !isProcessingSimulatorMockData else { return }
        isProcessingSimulatorMockData = true
        simulatorMockStatusMessage = nil

        Task { @MainActor in
            defer { isProcessingSimulatorMockData = false }
            do {
                try SimulatorAdvancedMockDataProvider.seed(into: ModelContext(modelContainer))
                isSimulatorMockEnabled = true
                simulatorMockStatusMessage = String(localized: "Mock data seeded.")
            } catch {
                simulatorMockStatusMessage = String(localized: "Mock data could not be updated.")
                AppLogger.data.error("Vision settings mock data seed failed: \(error.localizedDescription)")
            }
        }
    }

    private func resetAdvancedMockData() {
        guard SimulatorAdvancedMockDataModeStore.isSimulatorAvailable else { return }
        guard !isProcessingSimulatorMockData else { return }
        isProcessingSimulatorMockData = true
        simulatorMockStatusMessage = nil

        Task { @MainActor in
            defer { isProcessingSimulatorMockData = false }
            do {
                try SimulatorAdvancedMockDataProvider.reset(into: ModelContext(modelContainer))
                isSimulatorMockEnabled = false
                simulatorMockStatusMessage = String(localized: "Mock data reset.")
            } catch {
                simulatorMockStatusMessage = String(localized: "Mock data could not be updated.")
                AppLogger.data.error("Vision settings mock data reset failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func runWindowPlacementSmokeContinuationIfNeeded() async {
        guard smokeConfiguration.mode == .noAnchor else { return }

        try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeInitialDelayNanos)

        for windowID in smokeConfiguration.secondaryWindowAutoOpenIDs {
            guard !Task.isCancelled else { return }
            AppLogger.ui.info("[VisionWindowPlacementSmoke] Opening \(windowID) from settings utility panel")
            openWindow(id: windowID)
            try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeStepDelayNanos)
        }
    }
}
