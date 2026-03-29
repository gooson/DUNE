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
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: snapshot.condition.sfSymbol)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(snapshot.condition.iconColor(for: theme))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: isRegular ? 32 : 28)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(temperatureText(snapshot))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accentColor)
                            .monospacedDigit()

                        Text(snapshot.condition.label)
                            .font(.caption)
                            .foregroundStyle(theme.sandColor)

                        if let locationName = snapshot.locationName {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(locationName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if let aq = snapshot.airQuality {
                        airQualityBadge(aq)
                    }

                    fitnessBadge(for: snapshot)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-weather-card")
        } else {
            Button(action: onRequestLocationPermission) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "cloud.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .frame(width: 28)

                    Text("Weather")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("Tap to enable location")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Coaching Row

    @ViewBuilder
    private var coachingRow: some View {
        if let insight = effectiveInsight {
            Divider().opacity(0.3)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: insight.iconName)
                    .font(.title3)
                    .foregroundStyle(insight.category.iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(insight.message)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
        } else if let message = coachingMessage {
            Divider().opacity(0.3)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.activity)
                    .frame(width: 28)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                Spacer(minLength: 0)
            }
        }
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
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Briefing Footer

    @ViewBuilder
    private var briefingFooter: some View {
        if conditionStatus != nil {
            Divider().opacity(0.3)

            Button(action: onOpenBriefing) {
                HStack {
                    Spacer()
                    Text("View Details")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("briefing-entry-card")
            .accessibilityLabel(Text("Morning Briefing"))
            .accessibilityHint(Text("Opens your daily briefing"))
        }
    }

    // MARK: - Helpers

    /// The effective coaching insight to display — prioritizes non-weather insights;
    /// weather-category insights are shown only when no weather snapshot is available
    /// (otherwise they merge into the weather row via `weatherInsight`).
    private var effectiveInsight: CoachingInsight? {
        guard let insight = focusInsight else { return nil }
        if insight.category == .weather, weatherSnapshot != nil {
            // Weather-category insight merged via weatherInsight in weather row
            return nil
        }
        return insight
    }

    private func temperatureText(_ snapshot: WeatherSnapshot) -> String {
        let temp = "\(Int(snapshot.temperature))°C"
        if abs(snapshot.temperature - snapshot.feelsLike) >= 3 {
            return "\(temp) (Feels \(Int(snapshot.feelsLike))°)"
        }
        return temp
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
