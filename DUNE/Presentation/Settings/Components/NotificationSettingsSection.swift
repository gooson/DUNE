import SwiftUI

/// Per-type notification toggles for the Settings screen.
struct NotificationSettingsSection: View {
    @State private var settingsStore = NotificationSettingsStore.shared
    @AppStorage(BedtimeReminderScheduler.settingsKey) private var isBedtimeReminderEnabled = true
    @AppStorage(BedtimeReminderLeadTime.generalStorageKey)
    private var bedtimeReminderLeadTime: BedtimeReminderLeadTime = BedtimeReminderLeadTime.generalDefaultValue
    @AppStorage(AppleWatchBedtimeReminderScheduler.settingsKey)
    private var isAppleWatchBedtimeReminderEnabled = true
    @AppStorage(BedtimeReminderLeadTime.watchStorageKey)
    private var appleWatchBedtimeReminderLeadTime: BedtimeReminderLeadTime = BedtimeReminderLeadTime.watchDefaultValue
    @AppStorage(PostureReminderScheduler.settingsKey) private var isPostureReminderEnabled = false

    /// Grouped insight types for display.
    private static let healthTypes: [HealthInsight.InsightType] = [
        .hrvAnomaly, .rhrAnomaly, .sleepComplete, .sleepDebt, .stepGoal,
        .weightUpdate, .bodyFatUpdate, .bmiUpdate
    ]

    var body: some View {
        Group {
            notificationsSection
            bedtimeReminderSection
            postureReminderSection
        }
        .onChange(of: isBedtimeReminderEnabled) { _, _ in
            rescheduleBedtimeReminder()
        }
        .onChange(of: bedtimeReminderLeadTime) { _, _ in
            rescheduleBedtimeReminder()
        }
        .onChange(of: isAppleWatchBedtimeReminderEnabled) { _, _ in
            rescheduleAppleWatchBedtimeReminder()
        }
        .onChange(of: appleWatchBedtimeReminderLeadTime) { _, _ in
            rescheduleAppleWatchBedtimeReminder()
        }
        .onChange(of: isPostureReminderEnabled) { _, _ in
            reschedulePostureReminder()
        }
    }

    private var notificationsSection: some View {
        Section {
            ForEach(Self.healthTypes, id: \.self) { type in
                notificationToggle(for: type)
            }
            notificationToggle(for: .workoutPR)
            notificationToggle(for: .dailyDigest)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Health alerts are sent at most once per day, duplicates are suppressed for one hour, and informational alerts use a daily budget.")
        }
    }

    private var bedtimeReminderSection: some View {
        Section {
            Toggle(isOn: $isBedtimeReminderEnabled) {
                Label("Bedtime Reminder", systemImage: "moon.stars.fill")
            }
            .accessibilityIdentifier("settings-row-bedtime-reminder")

            Picker(selection: $bedtimeReminderLeadTime) {
                ForEach(BedtimeReminderLeadTime.allCases, id: \.self) { leadTime in
                    Text(leadTime.displayName).tag(leadTime)
                }
            } label: {
                Label("Reminder Lead Time", systemImage: "timer")
            }
            .accessibilityIdentifier("settings-row-bedtime-reminder-leadtime")
            .disabled(!isBedtimeReminderEnabled)

            Toggle(isOn: $isAppleWatchBedtimeReminderEnabled) {
                Label("Watch Reminder", systemImage: "applewatch")
            }
            .accessibilityIdentifier("settings-row-applewatch-bedtime-reminder")

            Picker(selection: $appleWatchBedtimeReminderLeadTime) {
                ForEach(BedtimeReminderLeadTime.allCases, id: \.self) { leadTime in
                    Text(leadTime.displayName).tag(leadTime)
                }
            } label: {
                Label("Watch Reminder Lead Time", systemImage: "timer")
            }
            .accessibilityIdentifier("settings-row-applewatch-bedtime-reminder-leadtime")
            .disabled(!isAppleWatchBedtimeReminderEnabled)
        } header: {
            Text("Bedtime")
        } footer: {
            if isAppleWatchBedtimeReminderEnabled {
                Text("DUNE skips this reminder when recent heart-rate data suggests you're already wearing your watch.")
            }
        }
    }

    private var postureReminderSection: some View {
        Section {
            Toggle(isOn: $isPostureReminderEnabled) {
                Label("Posture Reminder", systemImage: "figure.stand")
            }
            .accessibilityIdentifier("settings-row-posture-reminder")
        } header: {
            Text("Posture")
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

    private func rescheduleAppleWatchBedtimeReminder() {
        Task {
            await AppleWatchBedtimeReminderScheduler.shared.refreshSchedule(force: true)
        }
    }

    private func reschedulePostureReminder() {
        Task {
            await PostureReminderScheduler.shared.refreshSchedule()
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
        case .postureReminder: "Posture Reminder"
        case .dailyDigest: "Daily Digest"
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
        case .postureReminder: "figure.stand"
        case .dailyDigest: "doc.text"
        }
    }
}

#Preview {
    Form {
        NotificationSettingsSection()
    }
}
