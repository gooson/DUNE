import SwiftUI

/// Watch settings view for posture monitoring configuration.
struct PostureMonitorSettingsView: View {
    @State private var postureMonitor = WatchPostureMonitor.shared

    @State private var isEnabled: Bool
    @State private var thresholdMinutes: Int

    private static let thresholdOptions = [30, 45, 60, 90, 120]

    init() {
        let defaults = UserDefaults.standard
        _isEnabled = State(initialValue: defaults.bool(forKey: WatchPostureMonitor.SettingsKey.isEnabled))
        let stored = defaults.integer(forKey: WatchPostureMonitor.SettingsKey.sedentaryThresholdMinutes)
        _thresholdMinutes = State(initialValue: stored > 0 ? stored : 45)
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $isEnabled) {
                    Label(String(localized: "Posture Monitoring"), systemImage: "figure.stand")
                }
                .onChange(of: isEnabled) { _, newValue in
                    postureMonitor.setEnabled(newValue)
                }
            } footer: {
                Text(String(localized: "Tracks sitting time and walking posture using motion sensors."))
            }

            if isEnabled {
                Section {
                    Picker(String(localized: "Stretch Reminder"), selection: $thresholdMinutes) {
                        ForEach(Self.thresholdOptions, id: \.self) { minutes in
                            Text(String(localized: "\(minutes) min"))
                                .tag(minutes)
                        }
                    }
                    .onChange(of: thresholdMinutes) { _, newValue in
                        postureMonitor.setSedentaryThreshold(minutes: newValue)
                    }
                } header: {
                    Text(String(localized: "Remind me to stretch after"))
                }

                Section {
                    todaySummaryRow(
                        icon: "figure.seated.seatbelt",
                        label: String(localized: "Sitting"),
                        value: formatMinutes(postureMonitor.sedentaryMinutesToday)
                    )

                    todaySummaryRow(
                        icon: "figure.walk",
                        label: String(localized: "Walking"),
                        value: formatMinutes(postureMonitor.walkingMinutesToday)
                    )

                    if let score = postureMonitor.averageGaitScore {
                        todaySummaryRow(
                            icon: "waveform.path.ecg",
                            label: String(localized: "Gait Score"),
                            value: "\(score)/100"
                        )
                    }

                    todaySummaryRow(
                        icon: "bell",
                        label: String(localized: "Reminders Sent"),
                        value: "\(postureMonitor.stretchReminderCount)"
                    )
                } header: {
                    Text(String(localized: "Today"))
                }
            }
        }
        .navigationTitle(String(localized: "Posture"))
    }

    private func todaySummaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes) min")
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return String(localized: "\(hours)h")
        }
        return String(localized: "\(hours)h \(mins)m")
    }
}
