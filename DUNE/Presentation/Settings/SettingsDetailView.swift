import SwiftUI
import SwiftData
import CoreLocation

struct SettingsDetailView: View {
    let route: SettingsHubRoute
    let sharedHealthDataService: SharedHealthDataService?
    let canLoadHealthKitData: Bool
    let hasFailedHealthKitAuthorization: Bool
    let onOpen: (SettingsHubRoute) -> Void

    init(
        route: SettingsHubRoute,
        sharedHealthDataService: SharedHealthDataService? = nil,
        canLoadHealthKitData: Bool = true,
        hasFailedHealthKitAuthorization: Bool = false,
        recovery: SettingsWorkoutRecovery = SettingsWorkoutRecovery(),
        onOpen: @escaping (SettingsHubRoute) -> Void
    ) {
        self._recovery = State(initialValue: recovery)
        self.route = route
        self.sharedHealthDataService = sharedHealthDataService
        self.canLoadHealthKitData = canLoadHealthKitData
        self.hasFailedHealthKitAuthorization = hasFailedHealthKitAuthorization
        self.onOpen = onOpen
    }

    @AppStorage(CloudSyncPreferenceStore.storageKey) private var isCloudSyncEnabled = false
    @AppStorage(NearbyWorkoutTransfer.preferenceKey) private var nearbyWorkoutTransferEnabled = false
    @AppStorage(SimulatorAdvancedMockDataModeStore.storageKey) private var isSimulatorMockEnabled = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var restSeconds: Double = WorkoutSettingsStore.shared.restSeconds
    @State private var setCount: Int = WorkoutSettingsStore.shared.setCount
    @State private var bodyWeightKg: Double = WorkoutSettingsStore.shared.bodyWeightKg
    @State private var liveActivityPreferences = WorkoutLiveActivityPreferences.read()
    @State private var isProcessingSimulatorMockData = false
    @State private var simulatorMockStatusMessage: String?
    @State private var recovery: SettingsWorkoutRecovery
    @State private var isSyncing = false
    @State private var lastCloudSyncDate: Date?

    private let store = WorkoutSettingsStore.shared

    var body: some View {
        content
            .toolbar(.hidden, for: .tabBar)
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
            .onAppear {
                liveActivityPreferences = WorkoutLiveActivityPreferences.read()
                locationStatus = CLLocationManager().authorizationStatus
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    locationStatus = CLLocationManager().authorizationStatus
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .exerciseDefaults:
            ExerciseDefaultsListView()
        case .preferredExercises:
            PreferredExercisesListView()
        case .news:
            NotificationHubView(
                sharedHealthDataService: sharedHealthDataService,
                canLoadHealthKitData: canLoadHealthKitData,
                hasFailedHealthKitAuthorization: hasFailedHealthKitAuthorization,
                initialFilter: .news
            )
        default:
            settingsForm
        }
    }

    private var settingsForm: some View {
        Form {
            switch route {
            case .workout:
                workoutDefaultsSection
                exerciseDefaultsSection
                workoutLinksSection
            case .liveActivity:
                liveActivitySection
            case .alerts:
                morningBriefingSection
                alertLinksSection
            case .healthAlerts:
                NotificationSettingsSection(scope: .healthAlerts)
            case .bedtime:
                NotificationSettingsSection(scope: .bedtime)
            case .otherAlerts:
                NotificationSettingsSection(scope: .otherAlerts)
            case .privacy:
                dataPrivacySection
            case .about:
                aboutSection
            case .mockData:
                if SimulatorAdvancedMockDataModeStore.isSimulatorAvailable {
                    simulatorMockDataSection
                }
            default:
                EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.top, DS.Spacing.md, for: .scrollContent)
        .contentMargins(.horizontal, DS.Spacing.lg, for: .scrollContent)
        .contentMargins(.bottom, DS.Spacing.lg, for: .scrollContent)
        .listSectionSpacing(DS.Spacing.xl)
        .background { DetailWaveBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsSectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    // MARK: - Workout Defaults

    private var workoutDefaultsSection: some View {
        Section {
            Stepper(value: $restSeconds, in: WorkoutSettingsStore.restSecondsRange, step: 15) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Label("Rest Time", systemImage: "timer")
                        .labelStyle(.titleAndIcon)
                    Text(restTimeLabel)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .accessibilityIdentifier("settings-row-resttime")

            Stepper(value: $setCount, in: WorkoutSettingsStore.setCountRange) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Label("Default Sets", systemImage: "list.number")
                        .labelStyle(.titleAndIcon)
                    Text("\(setCount)")
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Stepper(value: $bodyWeightKg, in: WorkoutSettingsStore.bodyWeightRange, step: 0.5) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Label("Body Weight", systemImage: "figure.stand")
                        .labelStyle(.titleAndIcon)
                    Text("\(bodyWeightKg.formatted(.number.precision(.fractionLength(1)))) kg")
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        } header: {
            settingsSectionHeader("Workout Defaults")
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

    // MARK: - Live Activity

    private var liveActivitySection: some View {
        Section {
            Picker("Cardio Metric", selection: liveActivityMetricBinding(for: .cardio)) {
                ForEach([WorkoutLiveActivityMetric.elapsedTime, .distance, .heartRate], id: \.self) { metric in
                    Text(metric.displayName)
                        .tag(metric)
                        .accessibilityIdentifier("settings-watch-live-activity-cardio-\(metric.rawValue)")
                }
            }
            .accessibilityIdentifier("settings-watch-live-activity-cardio-metric")

            Picker("Strength Metric", selection: liveActivityMetricBinding(for: .strength)) {
                ForEach([WorkoutLiveActivityMetric.elapsedTime, .weight, .heartRate], id: \.self) { metric in
                    Text(metric.displayName)
                        .tag(metric)
                        .accessibilityIdentifier("settings-watch-live-activity-strength-\(metric.rawValue)")
                }
            }
            .accessibilityIdentifier("settings-watch-live-activity-strength-metric")

            Picker("Live Activity Style", selection: Binding(
                get: { liveActivityPreferences.style },
                set: { newValue in
                    liveActivityPreferences.style = newValue
                    saveLiveActivityPreferences()
                }
            )) {
                ForEach(WorkoutLiveActivityStyle.allCases, id: \.self) { style in
                    Text(style.displayName)
                        .tag(style)
                        .accessibilityIdentifier("settings-watch-live-activity-style-\(style.rawValue)")
                }
            }
            .accessibilityIdentifier("settings-watch-live-activity-style")
        } header: {
            settingsSectionHeader("Workout Live Activity")
        } footer: {
            Text("Unavailable readings show elapsed time instead.")
        }
    }

    private func liveActivityMetricBinding(for kind: WatchWorkoutSnapshot.WorkoutKind) -> Binding<WorkoutLiveActivityMetric> {
        Binding(
            get: {
                switch kind {
                case .cardio: liveActivityPreferences.cardioMetric
                case .strength: liveActivityPreferences.strengthMetric
                }
            },
            set: { newValue in
                switch kind {
                case .cardio: liveActivityPreferences.cardioMetric = newValue
                case .strength: liveActivityPreferences.strengthMetric = newValue
                }
                saveLiveActivityPreferences()
            }
        )
    }

    private func saveLiveActivityPreferences() {
        liveActivityPreferences.save()
        WatchWorkoutMirrorManager.shared.refreshLiveActivityPreferences()
    }

    // MARK: - Exercise Defaults

    private var exerciseDefaultsSection: some View {
        Section {
            Button {
                onOpen(.exerciseDefaults)
            } label: {
                Label("Exercise Defaults", systemImage: "dumbbell")
            }
            .accessibilityIdentifier("settings-row-exercisedefaults")

            Button {
                onOpen(.preferredExercises)
            } label: {
                Label("Preferred Exercises", systemImage: "star")
            }
            .accessibilityIdentifier("settings-row-preferredexercises")
        } header: {
            settingsSectionHeader("Per-Exercise")
        } footer: {
            Text("Set default values and choose exercises that should stay near the top of Quick Start.")
        }
    }

    private var workoutLinksSection: some View {
        Section {
            Button {
                onOpen(.liveActivity)
            } label: {
                Label("Workout Live Activity", systemImage: "figure.run")
            }
            .accessibilityIdentifier("settings-link-liveActivity")
        }
    }

    private var alertLinksSection: some View {
        Section {
            Button {
                onOpen(.healthAlerts)
            } label: {
                Label("Health Alerts", systemImage: "heart.text.square")
            }
            .accessibilityIdentifier("settings-link-healthAlerts")

            Button {
                onOpen(.bedtime)
            } label: {
                Label("Bedtime", systemImage: "moon.stars")
            }
            .accessibilityIdentifier("settings-link-bedtime")

            Button {
                onOpen(.otherAlerts)
            } label: {
                Label("Other Alerts", systemImage: "bell")
            }
            .accessibilityIdentifier("settings-link-otherAlerts")
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
            settingsSectionHeader("Morning Briefing")
        } footer: {
            Text("Show a daily briefing with your condition, recovery insights, and recommendations when you first open the app each morning.")
        }
    }

    // MARK: - Data & Privacy

    private var valueRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout())
    }

    private var simulatorMockDataSection: some View {
        Section {
            valueRowLayout {
                Text("Preset")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("Advanced Athlete")
                    .foregroundStyle(DS.Color.textSecondary)
            }

            valueRowLayout {
                Text("Status")
                    .accessibilityIdentifier("settings-mock-status-label")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
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
            settingsSectionHeader("Mock Data")
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
        Section {
            Toggle(isOn: cloudSyncBinding) {
                Label("iCloud Sync", systemImage: "icloud")
            }
            .accessibilityIdentifier("settings-row-icloud-sync")

            Toggle(isOn: $nearbyWorkoutTransferEnabled) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Nearby Workout Sync")
                    Text("Turn this on in DUNE on both devices. Workouts, metrics and recorded locations transfer directly to a nearby Mac using the same Apple Account and iCloud Keychain.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .accessibilityIdentifier("settings-row-nearby-workouts")

            Button {
                triggerCloudKitSync()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Sync")
                        if let lastSync = lastCloudSyncDate {
                            Text(lastSync, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                }
            }
            .disabled(isSyncing || !isCloudSyncEnabled)
            .accessibilityIdentifier("settings-row-force-sync")

            NavigationLink {
                CloudRecoverySettingsView()
            } label: {
                Label("Encrypted Backup File", systemImage: "lock.document")
            }
            .accessibilityIdentifier("settings-row-encrypted-backup")

            Button {
                Task {
                    await recovery.restore {
                        try await LegacyWorkoutRecovery.restore(into: modelContext.container)
                    }
                }
            } label: {
                Label("Restore workouts from an earlier iCloud backup", systemImage: "icloud.and.arrow.down")
            }
            .disabled(recovery.isRestoring)
            .accessibilityIdentifier("settings-row-restore-legacy-workouts")

            if recovery.isRestoring {
                ProgressView("Reading your earlier workout backup…")
            } else if let message = recovery.message {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("settings-legacy-workout-recovery-status")
            }


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
                valueRowLayout {
                    Label("Location Access", systemImage: "location")
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    Text(locationStatusText)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .accessibilityIdentifier("settings-row-location-access")
        } header: {
            settingsSectionHeader("Data & Privacy")
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

    private func triggerCloudKitSync() {
        guard !isSyncing else { return }
        isSyncing = true

        let favoritesSynced = QuickStartFavoriteSync.synchronize(in: modelContext)
        let routinesSynced = ExerciseLibraryBackup.synchronize(in: modelContext)
        if favoritesSynced && routinesSynced {
            lastCloudSyncDate = Date()
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSyncing = false
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            Button {
                onOpen(.news)
            } label: {
                Label("What's New", systemImage: "bell")
                    .accessibilityIdentifier("settings-row-whatsnew")
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
        } header: {
            settingsSectionHeader("About")
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
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
        SettingsDetailView(route: .workout, onOpen: { _ in })
    }
}

@Observable
@MainActor
final class SettingsWorkoutRecovery {
    private(set) var isRestoring = false
    private(set) var message: String?

    func restore(using operation: () async throws -> LegacyWorkoutRecovery.Result) async {
        guard !isRestoring else { return }
        isRestoring = true
        message = nil
        defer { isRestoring = false }
        do {
            let result = try await operation()
            let summary = String(localized: "Restored \(result.workouts) workouts and \(result.sets) sets to this device.")
            if result.locations > 0 {
                let locationLabel = String(localized: "Workout location")
                message = "\(summary)\n\(locationLabel) · \(result.locations.formatted())"
            } else {
                message = summary
            }
        } catch LegacyWorkoutRecovery.Failure.duplicateIdentity,
                LegacyWorkoutRecovery.Failure.invalidRelationship,
                LegacyWorkoutRecovery.Failure.localConflict,
                LegacyWorkoutRecovery.Failure.invalidRecord {
            message = String(localized: "Recovery stopped because the backup contains conflicting or unreadable records. Your local workouts are unchanged.")
        } catch {
            message = String(localized: "Couldn’t finish recovery. Check your iCloud connection and try again.")
        }
    }
}
