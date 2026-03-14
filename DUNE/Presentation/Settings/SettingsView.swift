import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
    @AppStorage(CloudSyncPreferenceStore.storageKey) private var isCloudSyncEnabled = false
    @AppStorage(SimulatorAdvancedMockDataModeStore.storageKey) private var isSimulatorMockEnabled = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var restSeconds: Double = WorkoutSettingsStore.shared.restSeconds
    @State private var setCount: Int = WorkoutSettingsStore.shared.setCount
    @State private var bodyWeightKg: Double = WorkoutSettingsStore.shared.bodyWeightKg
    @State private var isProcessingSimulatorMockData = false
    @State private var simulatorMockStatusMessage: String?

    private let store = WorkoutSettingsStore.shared
    private let whatsNewStore = WhatsNewStore.shared
    private let whatsNewManager = WhatsNewManager.shared

    var body: some View {
        Form {
            workoutDefaultsSection
            exerciseDefaultsSection
            NotificationSettingsSection()
            morningBriefingSection
            appearanceSection
            if SimulatorAdvancedMockDataModeStore.isSimulatorAvailable {
                simulatorMockDataSection
            }
            dataPrivacySection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Settings")
        .onChange(of: restSeconds) { _, newValue in
            store.restSeconds = newValue
            WatchSessionManager.shared.syncWorkoutSettingsToWatch()
        }
        .onChange(of: setCount) { _, newValue in
            store.setCount = newValue
        }
        .onChange(of: bodyWeightKg) { _, newValue in
            store.bodyWeightKg = newValue
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                locationStatus = CLLocationManager().authorizationStatus
            }
        }
    }

    // MARK: - Workout Defaults

    private var workoutDefaultsSection: some View {
        Section {
            HStack {
                Label("Rest Time", systemImage: "timer")
                Spacer()
                Text(restTimeLabel)
                    .foregroundStyle(DS.Color.textSecondary)
                Stepper("", value: $restSeconds, in: WorkoutSettingsStore.restSecondsRange, step: 15)
                    .labelsHidden()
            }
            .accessibilityIdentifier("settings-row-resttime")

            HStack {
                Label("Default Sets", systemImage: "list.number")
                Spacer()
                Text("\(setCount)")
                    .foregroundStyle(DS.Color.textSecondary)
                Stepper("", value: $setCount, in: WorkoutSettingsStore.setCountRange)
                    .labelsHidden()
            }

            HStack {
                Label("Body Weight", systemImage: "figure.stand")
                Spacer()
                Text("\(bodyWeightKg.formatted(.number.precision(.fractionLength(1)))) kg")
                    .foregroundStyle(DS.Color.textSecondary)
                Stepper(
                    "",
                    value: $bodyWeightKg,
                    in: WorkoutSettingsStore.bodyWeightRange,
                    step: 0.5
                )
                .labelsHidden()
            }
        } header: {
            Text("Workout Defaults")
        } footer: {
            Text("These values are used as defaults when starting a new workout session.")
        }
    }

    private var restTimeLabel: String {
        let minutes = Int(restSeconds) / 60
        let seconds = Int(restSeconds) % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Exercise Defaults

    private var exerciseDefaultsSection: some View {
        Section {
            NavigationLink {
                ExerciseDefaultsListView()
            } label: {
                Label("Exercise Defaults", systemImage: "dumbbell")
            }
            .accessibilityIdentifier("settings-row-exercisedefaults")

            NavigationLink {
                PreferredExercisesListView()
            } label: {
                Label("Preferred Exercises", systemImage: "star")
            }
            .accessibilityIdentifier("settings-row-preferredexercises")
        } header: {
            Text("Per-Exercise")
        } footer: {
            Text("Set default values and choose exercises that should stay near the top of Quick Start.")
        }
    }

    // MARK: - Morning Briefing

    @State private var isMorningBriefingEnabled = MorningBriefingViewModel.isEnabled

    private var morningBriefingSection: some View {
        Section {
            Toggle(isOn: $isMorningBriefingEnabled) {
                Label("Morning Briefing", systemImage: "sun.horizon.fill")
            }
            .onChange(of: isMorningBriefingEnabled) { _, newValue in
                MorningBriefingViewModel.isEnabled = newValue
            }
            .accessibilityIdentifier("settings-row-morning-briefing")
        } header: {
            Text("Morning Briefing")
        } footer: {
            Text("Show a daily briefing with your condition, recovery insights, and recommendations when you first open the app each morning.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            ThemePickerSection()
                .accessibilityIdentifier("settings-section-appearance")
        }
    }

    // MARK: - Data & Privacy

    private var simulatorMockDataSection: some View {
        Section {
            HStack {
                Text("Preset")
                Spacer()
                Text("Advanced Athlete")
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack {
                Text("Status")
                Spacer()
                Text(isSimulatorMockEnabled ? "Enabled" : "Disabled")
                    .foregroundStyle(isSimulatorMockEnabled ? Color.accentColor : DS.Color.textSecondary)
            }

            Button {
                seedAdvancedMockData()
            } label: {
                Label("Seed Advanced Mock Data", systemImage: "shippingbox.fill")
            }
            .accessibilityIdentifier("settings-button-seed-advanced-mock-data")
            .disabled(isProcessingSimulatorMockData)

            Button(role: .destructive) {
                resetAdvancedMockData()
            } label: {
                Label("Reset Mock Data", systemImage: "trash")
            }
            .accessibilityIdentifier("settings-button-reset-mock-data")
            .disabled(isProcessingSimulatorMockData || !isSimulatorMockEnabled)
        } header: {
            Text("Mock Data")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Simulator only. Seeds advanced athlete health trends, workouts, and per-exercise history.")
                if let simulatorMockStatusMessage {
                    Text(verbatim: simulatorMockStatusMessage)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
    }

    private var dataPrivacySection: some View {
        Section("Data & Privacy") {
            Toggle(isOn: cloudSyncBinding) {
                Label("iCloud Sync", systemImage: "icloud")
            }
            .accessibilityIdentifier("settings-row-icloud-sync")

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                Label("HealthKit Permissions", systemImage: "heart.circle")
            }

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                HStack {
                    Label("Location Access", systemImage: "location")
                    Spacer()
                    Text(locationStatusText)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .accessibilityIdentifier("settings-row-location-access")
        }
    }

    private var locationStatusText: String {
        switch locationStatus {
        case .authorizedWhenInUse: String(localized: "When In Use")
        case .authorizedAlways: String(localized: "Always")
        case .denied: String(localized: "Denied")
        case .restricted: String(localized: "Restricted")
        case .notDetermined: String(localized: "Not Set")
        @unknown default: String(localized: "Unknown")
        }
    }

    private var cloudSyncBinding: Binding<Bool> {
        Binding(
            get: { isCloudSyncEnabled },
            set: { newValue in
                CloudSyncPreferenceStore.setEnabled(newValue)
                isCloudSyncEnabled = newValue
            }
        )
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            if !whatsNewReleases.isEmpty {
                NavigationLink {
                    WhatsNewView(
                        releases: whatsNewReleases,
                        mode: .manual,
                        onPresented: markWhatsNewOpened
                    )
                } label: {
                    Label("What's New", systemImage: "sparkles")
                        .accessibilityIdentifier("settings-row-whatsnew")
                }
            }

            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings-row-version")

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack {
                Text("Weather Data")
                Spacer()
                Text("Open-Meteo.com (CC BY 4.0)")
                    .foregroundStyle(DS.Color.textSecondary)
                    .font(.caption)
            }
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var whatsNewReleases: [WhatsNewReleaseData] {
        whatsNewManager.orderedReleases(preferredVersion: appVersion)
    }

    private func markWhatsNewOpened() {
        let build = whatsNewManager.currentBuildNumber()
        guard !build.isEmpty else { return }
        whatsNewStore.markOpened(build: build)
    }

    private func seedAdvancedMockData() {
        isProcessingSimulatorMockData = true
        simulatorMockStatusMessage = nil

        Task { @MainActor in
            defer { isProcessingSimulatorMockData = false }
            do {
                try SimulatorAdvancedMockDataProvider.seed(into: modelContext)
                isSimulatorMockEnabled = true
                simulatorMockStatusMessage = String(localized: "Mock data seeded.")
            } catch {
                simulatorMockStatusMessage = String(localized: "Mock data could not be updated.")
                AppLogger.data.error("Simulator mock data seed failed: \(error.localizedDescription)")
            }
        }
    }

    private func resetAdvancedMockData() {
        isProcessingSimulatorMockData = true
        simulatorMockStatusMessage = nil

        Task { @MainActor in
            defer { isProcessingSimulatorMockData = false }
            do {
                try SimulatorAdvancedMockDataProvider.reset(into: modelContext)
                isSimulatorMockEnabled = false
                simulatorMockStatusMessage = String(localized: "Mock data reset.")
            } catch {
                simulatorMockStatusMessage = String(localized: "Mock data could not be updated.")
                AppLogger.data.error("Simulator mock data reset failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
