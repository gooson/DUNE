import SwiftUI

/// Watch settings view for posture monitoring configuration.
struct PostureMonitorSettingsView: View {
    @State private var postureMonitor = WatchPostureMonitor.shared

    @State private var isEnabled: Bool
    @State private var thresholdMinutes: Int

    private static let thresholdOptions = [30, 45, 60, 90, 120]

    init() {
        let monitor = WatchPostureMonitor.shared
        _isEnabled = State(initialValue: monitor.isEnabled)
        _thresholdMinutes = State(initialValue: monitor.sedentaryThresholdMinutes)
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $isEnabled) {
                    Label("Posture Monitoring", systemImage: "figure.stand")
                }
                .onChange(of: isEnabled) { _, newValue in
                    postureMonitor.setEnabled(newValue)
                }
            } footer: {
                Text("Tracks sitting time and walking posture using motion sensors.")
            }

            if isEnabled {
                Section {
                    Picker(selection: $thresholdMinutes) {
                        ForEach(Self.thresholdOptions, id: \.self) { minutes in
                            Text("\(minutes) min")
                                .tag(minutes)
                        }
                    } label: {
                        Text("Stretch Reminder")
                    }
                    .onChange(of: thresholdMinutes) { _, newValue in
                        postureMonitor.setSedentaryThreshold(minutes: newValue)
                    }
                } header: {
                    Text("Remind me to stretch after")
                }

                Section {
                    todaySummaryRow(
                        icon: "figure.seated.seatbelt",
                        label: "Sitting",
                        value: PostureFormatting.formatMinutes(postureMonitor.sedentaryMinutesToday)
                    )

                    todaySummaryRow(
                        icon: "figure.walk",
                        label: "Walking",
                        value: PostureFormatting.formatMinutes(postureMonitor.walkingMinutesToday)
                    )

                    if let score = postureMonitor.cachedAverageGaitScore {
                        todaySummaryRow(
                            icon: "waveform.path.ecg",
                            label: "Gait Score",
                            value: "\(score)/100"
                        )
                    }

                    todaySummaryRow(
                        icon: "bell",
                        label: "Reminders Sent",
                        value: "\(postureMonitor.stretchReminderCount)"
                    )
                } header: {
                    Text("Today")
                }
            }
        }
        .navigationTitle(String(localized: "Posture"))
    }

    private func todaySummaryRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
