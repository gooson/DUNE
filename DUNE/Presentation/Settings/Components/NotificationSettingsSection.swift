import SwiftUI

/// Per-type notification toggles for the Settings screen.
struct NotificationSettingsSection: View {
    @State private var settingsStore = NotificationSettingsStore.shared
    @AppStorage("isBedtimeWatchReminderEnabled") private var isBedtimeReminderEnabled = true

    /// Grouped insight types for display.
    private static let healthTypes: [HealthInsight.InsightType] = [
        .hrvAnomaly, .rhrAnomaly, .sleepComplete, .sleepDebt, .stepGoal,
        .weightUpdate, .bodyFatUpdate, .bmiUpdate
    ]

    var body: some View {
        Section {
            ForEach(Self.healthTypes, id: \.self) { type in
                notificationToggle(for: type)
            }
            notificationToggle(for: .workoutPR)
            Toggle(isOn: $isBedtimeReminderEnabled) {
                Label("Bedtime Watch Reminder", systemImage: "applewatch")
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Health alerts are sent at most once per day, duplicates are suppressed for one hour, and informational alerts use a daily budget.")
        }
    }

    private func notificationToggle(for type: HealthInsight.InsightType) -> some View {
        Toggle(isOn: Binding(
            get: { settingsStore.isEnabled(for: type) },
            set: { settingsStore.setEnabled($0, for: type) }
        )) {
            Label(type.settingsDisplayName, systemImage: type.settingsIcon)
        }
    }
}

// MARK: - Display Properties

extension HealthInsight.InsightType {
    /// Localized name for the Settings toggle label.
    var settingsDisplayName: LocalizedStringKey {
        switch self {
        case .hrvAnomaly: "HRV Anomaly"
        case .rhrAnomaly: "Resting HR Alert"
        case .sleepComplete: "Sleep Recorded"
        case .sleepDebt: "Sleep Debt"
        case .stepGoal: "Step Goal"
        case .weightUpdate: "Weight Update"
        case .bodyFatUpdate: "Body Fat Update"
        case .bmiUpdate: "BMI Update"
        case .workoutPR: "Workout Records"
        }
    }

    /// SF Symbol for the Settings toggle.
    var settingsIcon: String {
        switch self {
        case .hrvAnomaly: "waveform.path.ecg"
        case .rhrAnomaly: "heart.fill"
        case .sleepComplete: "moon.fill"
        case .sleepDebt: "moon.zzz.fill"
        case .stepGoal: "figure.walk"
        case .weightUpdate: "scalemass"
        case .bodyFatUpdate: "percent"
        case .bmiUpdate: "number"
        case .workoutPR: "trophy.fill"
        }
    }
}

#Preview {
    Form {
        NotificationSettingsSection()
    }
}
