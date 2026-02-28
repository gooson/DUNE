import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled = false
    @Environment(\.openURL) private var openURL

    @State private var restSeconds: Double = WorkoutSettingsStore.shared.restSeconds
    @State private var setCount: Int = WorkoutSettingsStore.shared.setCount
    @State private var bodyWeightKg: Double = WorkoutSettingsStore.shared.bodyWeightKg

    private let store = WorkoutSettingsStore.shared

    var body: some View {
        Form {
            workoutDefaultsSection
            exerciseDefaultsSection
            appearanceSection
            dataPrivacySection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .navigationTitle("Settings")
        .onChange(of: restSeconds) { _, newValue in
            store.restSeconds = newValue
        }
        .onChange(of: setCount) { _, newValue in
            store.setCount = newValue
        }
        .onChange(of: bodyWeightKg) { _, newValue in
            store.bodyWeightKg = newValue
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
        } header: {
            Text("Per-Exercise")
        } footer: {
            Text("Set default weight for each exercise. Last used weight is remembered automatically.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            ThemePickerSection()
        }
    }

    // MARK: - Data & Privacy

    private var dataPrivacySection: some View {
        Section("Data & Privacy") {
            Toggle(isOn: $isCloudSyncEnabled) {
                Label("iCloud Sync", systemImage: "icloud")
            }

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                Label("HealthKit Permissions", systemImage: "heart.circle")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack {
                Text("Weather Data")
                Spacer()
                Text("Apple WeatherKit, Open-Meteo.com")
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
