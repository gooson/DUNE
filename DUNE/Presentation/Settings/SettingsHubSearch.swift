import SwiftUI

struct SettingsHubSearchEntry: Identifiable {
    let id: String
    let title: String
    let category: String
    let route: SettingsHubRoute
    let aliases: [String]
}

/// The searchable names mirror the labels in the native settings controls.
enum SettingsHubSearchIndex {
    static func entries(bundle: Bundle = .main, includeSimulator: Bool = SimulatorAdvancedMockDataModeStore.isSimulatorAvailable) -> [SettingsHubSearchEntry] {
        let workout: LocalizedStringResource = "Workout Defaults"
        let liveActivity: LocalizedStringResource = "Workout Live Activity"
        let perExercise: LocalizedStringResource = "Per-Exercise"
        let alerts: LocalizedStringResource = "Notifications"
        let healthAlerts: LocalizedStringResource = "Health Alerts"
        let otherAlerts: LocalizedStringResource = "Other Alerts"
        let bedtime: LocalizedStringResource = "Bedtime"
        let posture: LocalizedStringResource = "Posture"
        let privacy: LocalizedStringResource = "Data & Privacy"
        let about: LocalizedStringResource = "About"
        let appearance: LocalizedStringResource = "Appearance"
        let theme: LocalizedStringResource = "Theme"
        let mock: LocalizedStringResource = "Mock Data"

        func localized(_ resource: LocalizedStringResource) -> String {
            bundle.localizedString(forKey: resource.key, value: resource.key, table: "Localizable")
        }

        func item(_ id: String, _ title: LocalizedStringResource, _ category: LocalizedStringResource, _ route: SettingsHubRoute, aliases: [String] = []) -> SettingsHubSearchEntry {
            SettingsHubSearchEntry(
                id: id,
                title: localized(title),
                category: localized(category),
                route: route,
                aliases: [title.key, category.key] + aliases
            )
        }

        var result: [SettingsHubSearchEntry] = [
            item("theme", theme, appearance, .gallery),
            item("app-icon", LocalizedStringResource("App Icon"), appearance, .icons),
            item("workout", workout, workout, .workout, aliases: ["Workout Settings"]),
            item("rest-time", LocalizedStringResource("Rest Time"), workout, .workout),
            item("default-sets", LocalizedStringResource("Default Sets"), workout, .workout),
            item("body-weight", LocalizedStringResource("Body Weight"), workout, .workout),
            item("exercise-defaults", LocalizedStringResource("Exercise Defaults"), perExercise, .exerciseDefaults),
            item("preferred-exercises", LocalizedStringResource("Preferred Exercises"), perExercise, .preferredExercises),
            item("live-activity", liveActivity, workout, .liveActivity),
            item("cardio-metric", LocalizedStringResource("Cardio Metric"), liveActivity, .liveActivity),
            item("strength-metric", LocalizedStringResource("Strength Metric"), liveActivity, .liveActivity),
            item("live-activity-style", LocalizedStringResource("Live Activity Style"), liveActivity, .liveActivity),
            item("morning-briefing", LocalizedStringResource("Morning Briefing"), alerts, .alerts),
            item("hrv-anomaly", LocalizedStringResource("HRV Anomaly"), healthAlerts, .healthAlerts),
            item("resting-hr-alert", LocalizedStringResource("Resting HR Alert"), healthAlerts, .healthAlerts),
            item("sleep-recorded", LocalizedStringResource("Sleep Recorded"), healthAlerts, .healthAlerts),
            item("sleep-debt", LocalizedStringResource("Sleep Debt"), healthAlerts, .healthAlerts),
            item("step-goal", LocalizedStringResource("Step Goal"), healthAlerts, .healthAlerts),
            item("weight-update", LocalizedStringResource("Weight Update"), healthAlerts, .healthAlerts),
            item("body-fat-update", LocalizedStringResource("Body Fat Update"), healthAlerts, .healthAlerts),
            item("bmi-update", LocalizedStringResource("BMI Update"), healthAlerts, .healthAlerts),
            item("bedtime", LocalizedStringResource("Bedtime Reminder"), bedtime, .bedtime, aliases: ["iPhone Bedtime"]),
            item("bedtime-lead-time", LocalizedStringResource("Reminder Lead Time"), bedtime, .bedtime, aliases: ["iPhone Bedtime"]),
            item("bedtime-watch", LocalizedStringResource("Watch Reminder"), bedtime, .bedtime, aliases: ["Apple Watch Bedtime"]),
            item("bedtime-watch-lead-time", LocalizedStringResource("Watch Reminder Lead Time"), bedtime, .bedtime, aliases: ["Apple Watch Bedtime"]),
            item("workout-records", LocalizedStringResource("Workout Records"), otherAlerts, .otherAlerts),
            item("daily-digest", LocalizedStringResource("Daily Digest"), otherAlerts, .otherAlerts),
            item("posture-reminder", LocalizedStringResource("Posture Reminder"), posture, .otherAlerts, aliases: [localized(otherAlerts), otherAlerts.key]),
            item("icloud-sync", LocalizedStringResource("iCloud Sync"), privacy, .privacy),
            item("force-sync", LocalizedStringResource("Force Sync"), privacy, .privacy),
            item("healthkit-permissions", LocalizedStringResource("HealthKit Permissions"), privacy, .privacy, aliases: ["Apple Health"]),
            item("location-access", LocalizedStringResource("Location Access"), privacy, .privacy),
            item("whats-new", LocalizedStringResource("What's New"), about, .news, aliases: ["News"]),
            item("version", LocalizedStringResource("Version"), about, .about),
            item("build", LocalizedStringResource("Build"), about, .about),
            item("weather-data", LocalizedStringResource("Weather Data"), about, .about)
        ]

        result.append(contentsOf: AppTheme.allCases.map { themeValue in
            item("theme-\(themeValue.rawValue)", themeValue.displayNameResource, theme, .preview(themeValue), aliases: [themeValue.rawValue])
        })

        if includeSimulator {
            result.append(contentsOf: [
                item("mock-preset", LocalizedStringResource("Preset"), mock, .mockData),
                item("mock-status", LocalizedStringResource("Status"), mock, .mockData),
                item("mock-seed", LocalizedStringResource("Seed Advanced Mock Data"), mock, .mockData),
                item("mock-reset", LocalizedStringResource("Reset Mock Data"), mock, .mockData)
            ])
        }
        return result
    }

    static func results(for query: String, bundle: Bundle = .main, includeSimulator: Bool = SimulatorAdvancedMockDataModeStore.isSimulatorAvailable) -> [SettingsHubSearchEntry] {
        let locale = Locale(identifier: bundle.preferredLocalizations.first ?? "en")
        let words = normalized(query, locale: locale).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        return entries(bundle: bundle, includeSimulator: includeSimulator).filter { entry in
            let haystack = normalized(([entry.title, entry.category] + entry.aliases).joined(separator: " "), locale: locale)
            let compact = haystack.replacingOccurrences(of: " ", with: "")
            return words.allSatisfy { haystack.contains($0) || compact.contains($0) }
        }
    }

    private static func normalized(_ value: String, locale: Locale) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

struct SettingsHubSearchView: View {
    @Binding var query: String
    let onOpen: (SettingsHubRoute) -> Void

    private var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DS.Color.textSecondary)
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("settings-search-field")
                }
            }

            if isQueryEmpty {
                Section("Suggested Searches") {
                    suggestion("Theme", query: String(localized: "Theme"))
                    suggestion("Bedtime", query: String(localized: "Bedtime"))
                    suggestion("iCloud Sync", query: String(localized: "iCloud Sync"))
                    suggestion("Rest Time", query: String(localized: "Rest Time"))
                }
            } else {
                let matches = SettingsHubSearchIndex.results(for: query)
                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    Section {
                        ForEach(matches) { entry in
                            Button {
                                onOpen(entry.route)
                            } label: {
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(entry.title)
                                        .foregroundStyle(.primary)
                                    Text(entry.category)
                                        .font(.caption)
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .accessibilityIdentifier("settings-search-result-\(entry.id)")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
    }

    private func suggestion(_ title: LocalizedStringKey, query suggestedQuery: String) -> some View {
        Button(title) { query = suggestedQuery }
    }
}

#Preview {
    NavigationStack {
        SettingsHubSearchView(query: .constant("Bedtime"), onOpen: { _ in })
    }
}
