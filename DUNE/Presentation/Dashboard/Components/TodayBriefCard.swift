import SwiftUI

/// Consolidated "Today's Brief" card combining weather, coaching, and briefing entry.
/// Replaces the separate BriefingEntryCard + WeatherCard + TodayCoachingCard trio.
struct TodayBriefCard: View {
    let weatherSnapshot: WeatherSnapshot?
    let weatherInsight: WeatherCard.InsightInfo?
    let focusInsight: CoachingInsight?
    let coachingMessage: String?
    let conditionStatus: ConditionScore.Status?
    let onOpenBriefing: () -> Void
    let onOpenWeatherDetail: () -> Void
    let onRequestLocationPermission: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        DashboardSupportCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentColor)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather and Activity")
                            .font(.headline)
                        if let locationName = weatherSnapshot?.locationName {
                            Text(locationName)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                        } else {
                            Text("Current conditions")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                    }
                }
                weatherRow
                coachingRow
                environmentAlert
                briefingFooter
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard-today-brief-card")
    }

    // MARK: - Weather Row

    @ViewBuilder
    private var weatherRow: some View {
        if let snapshot = weatherSnapshot {
            Button(action: onOpenWeatherDetail) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: snapshot.condition.sfSymbol)
                            .font(.title3)
                            .foregroundStyle(snapshot.condition.iconColor(for: theme))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 26)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    temperatureAndCondition(snapshot)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    temperatureAndCondition(snapshot)
                                }
                            }

                            if abs(snapshot.temperature - snapshot.feelsLike) >= 3 {
                                Text("Feels \(Int(snapshot.feelsLike))°")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryTextColor)
                            }
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryTextColor)
                            .accessibilityHidden(true)
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 4) {
                            if let aq = snapshot.airQuality { airQualityBadge(aq) }
                            fitnessBadge(for: snapshot)
                        }
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                if let aq = snapshot.airQuality { airQualityBadge(aq) }
                                fitnessBadge(for: snapshot)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                if let aq = snapshot.airQuality { airQualityBadge(aq) }
                                fitnessBadge(for: snapshot)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-weather-card")
        } else {
            Button(action: onRequestLocationPermission) {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.fill")
                        .font(.title3)
                        .foregroundStyle(theme.secondaryTextColor)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather unavailable")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap to enable location")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryTextColor)
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-weather-permission")
        }
    }

    // MARK: - Coaching Row

    @ViewBuilder
    private var coachingRow: some View {
        if let insight = effectiveInsight {
            Divider().opacity(0.3)
            suggestionRow(icon: insight.iconName, title: insight.title,
                          message: insight.message, color: insight.category.iconColor)
        } else if let weatherInsight {
            Divider().opacity(0.3)
            suggestionRow(icon: weatherInsight.iconName, title: weatherInsight.title,
                          message: weatherInsight.message,
                          color: weatherSnapshot.map { theme.outdoorFitnessColor(for: $0.outdoorFitnessLevel) } ?? theme.accentColor)
        } else if let message = coachingMessage {
            Divider().opacity(0.3)
            suggestionRow(icon: "figure.run.circle.fill", title: nil,
                          message: message, color: DS.Color.activity)
        }
    }

    private func suggestionRow(icon: String, title: String?, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Today's Suggestion", systemImage: "lightbulb.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryTextColor)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard-today-suggestion")
    }

    // MARK: - Environment Alert (conditional)

    @ViewBuilder
    private var environmentAlert: some View {
        if let alert = environmentAlertInfo {
            Divider().opacity(0.3)

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: alert.icon)
                    .font(.caption)
                    .foregroundStyle(alert.color)
                    .frame(width: 20)

                Text(alert.message)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Briefing Footer

    @ViewBuilder
    private var briefingFooter: some View {
        if conditionStatus != nil {
            Divider().opacity(0.3)

            Button(action: onOpenBriefing) {
                HStack(spacing: 8) {
                    Text("View Briefing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("briefing-entry-card")
            .accessibilityLabel(Text("View Briefing"))
            .accessibilityHint(Text("Opens your daily briefing"))
        }
    }

    // MARK: - Helpers

    /// Prioritize non-weather coaching. Weather coaching uses the suggestion fallback
    /// when the weather snapshot is already represented above.
    private var effectiveInsight: CoachingInsight? {
        guard let insight = focusInsight else { return nil }
        if insight.category == .weather, weatherSnapshot != nil {
            // The weather-specific insight is displayed by coachingRow.
            return nil
        }
        return insight
    }

    private func temperatureText(_ snapshot: WeatherSnapshot) -> String {
        "\(Int(snapshot.temperature))°C"
    }

    @ViewBuilder
    private func temperatureAndCondition(_ snapshot: WeatherSnapshot) -> some View {
        Text(temperatureText(snapshot))
            .font(.system(.title3, design: .rounded, weight: .bold))
            .monospacedDigit()
        Text(snapshot.condition.label)
            .font(.subheadline)
            .foregroundStyle(theme.secondaryTextColor)
    }

    private func fitnessBadge(for snapshot: WeatherSnapshot) -> some View {
        let level = snapshot.outdoorFitnessLevel
        let color = theme.outdoorFitnessColor(for: level)
        return Label(level.shortDisplayName, systemImage: level.systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background {
                Capsule()
                    .fill(color.opacity(DS.Opacity.subtle))
            }
    }

    private func airQualityBadge(_ aq: AirQualitySnapshot) -> some View {
        let aqLevel = aq.overallLevel
        let color = aqLevel.color(for: theme)
        return Label {
            Text("PM₂.₅ \(Int(aq.pm2_5))")
        } icon: {
            Image(systemName: aqLevel.sfSymbol)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs)
        .background {
            Capsule()
                .fill(color.opacity(DS.Opacity.subtle))
        }
    }

    // MARK: - Environment Alert Logic

    private struct EnvironmentAlert {
        let icon: String
        let message: String
        let color: Color
    }

    private var environmentAlertInfo: EnvironmentAlert? {
        guard let snapshot = weatherSnapshot else { return nil }

        // High humidity (snapshot.humidity is 0-1 scale)
        let humidityPercent = Int(snapshot.humidity * 100)
        if humidityPercent > 70 {
            return EnvironmentAlert(
                icon: "humidity.fill",
                message: String(localized: "High humidity \(humidityPercent)% — stay hydrated during outdoor exercise"),
                color: DS.Color.caution
            )
        }

        // Poor air quality
        if let aq = snapshot.airQuality, aq.overallLevel >= .unhealthy {
            return EnvironmentAlert(
                icon: "aqi.medium",
                message: String(localized: "Poor air quality — consider indoor exercise today"),
                color: DS.Color.caution
            )
        }

        // Extreme temperature
        if snapshot.temperature >= 35 {
            return EnvironmentAlert(
                icon: "thermometer.sun.fill",
                message: String(localized: "Extreme heat — hydrate frequently and avoid peak hours"),
                color: DS.Color.caution
            )
        }
        if snapshot.temperature <= -5 {
            return EnvironmentAlert(
                icon: "thermometer.snowflake",
                message: String(localized: "Extreme cold — warm up thoroughly before outdoor exercise"),
                color: DS.Color.vitals
            )
        }

        return nil
    }
}

#Preview("No location") {
    TodayBriefCard(
        weatherSnapshot: nil, weatherInsight: nil, focusInsight: nil,
        coachingMessage: nil, conditionStatus: nil,
        onOpenBriefing: {}, onOpenWeatherDetail: {}, onRequestLocationPermission: {}
    )
    .padding()
}
