import SwiftUI

/// Per-type notification toggles for the Settings screen.
struct NotificationSettingsSection: View {
    @State private var settingsStore = NotificationSettingsStore.shared
    @AppStorage(BedtimeReminderScheduler.settingsKey) private var isBedtimeReminderEnabled = true
    @AppStorage(BedtimeReminderLeadTime.storageKey)
    private var bedtimeReminderLeadTime: BedtimeReminderLeadTime = BedtimeReminderLeadTime.defaultValue

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
                Label("Bedtime Reminder", systemImage: "moon.stars.fill")
            }
            Picker("Reminder Lead Time", selection: $bedtimeReminderLeadTime) {
                ForEach(BedtimeReminderLeadTime.allCases, id: \.self) { leadTime in
                    Text(leadTime.displayName).tag(leadTime)
                }
            }
            .disabled(!isBedtimeReminderEnabled)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Health alerts are sent at most once per day, duplicates are suppressed for one hour, and informational alerts use a daily budget.")
        }
        .onChange(of: isBedtimeReminderEnabled) { _, _ in
            rescheduleBedtimeReminder()
        }
        .onChange(of: bedtimeReminderLeadTime) { _, _ in
            rescheduleBedtimeReminder()
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

    private func rescheduleBedtimeReminder() {
        Task {
            await BedtimeReminderScheduler.shared.refreshSchedule(force: true)
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
        case .lifeChecklistReminder: "Life Checklist"
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
        case .lifeChecklistReminder: "checklist"
        }
    }
}

#Preview {
    Form {
        NotificationSettingsSection()
    }
}
