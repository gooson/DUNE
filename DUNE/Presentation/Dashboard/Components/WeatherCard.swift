import SwiftUI

/// Full-width weather card for the Today tab.
/// Shows current conditions, temperature, outdoor fitness badge, and optional coaching insight.
/// Tapping navigates to WeatherDetailView.
struct WeatherCard: View {
    /// Display-ready coaching insight data (decoupled from Domain CoachingInsight).
    struct InsightInfo {
        let title: String
        let message: String
        let iconName: String
    }

    let snapshot: WeatherSnapshot
    var insightInfo: InsightInfo?

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }
    private var level: OutdoorFitnessLevel { snapshot.outdoorFitnessLevel }

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    // Weather icon
                    Image(systemName: snapshot.condition.sfSymbol)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(snapshot.condition.iconColor(for: theme))
                        .symbolRenderingMode(.multicolor)

                    // Temperature + condition + location
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(temperatureText)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.accentColor)
                                .monospacedDigit()

                            if feelsLikeDiffers {
                                Text("Feels \(Int(snapshot.feelsLike))°")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.sandColor)
                            }
                        }

                        HStack(spacing: DS.Spacing.xxs) {
                            Text(snapshot.condition.label)
                                .font(.subheadline)
                                .foregroundStyle(theme.sandColor)

                            if let locationName = snapshot.locationName {
                                Text("·")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)

                                Text(locationName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    // Air quality badge (when available)
                    if let aq = snapshot.airQuality {
                        airQualityBadge(aq)
                    }

                    // Outdoor fitness badge
                    fitnessBadge

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                // Coaching insight (weather-category only)
                if let info = insightInfo {
                    Divider().opacity(0.3)

                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: info.iconName)
                            .font(.subheadline)
                            .foregroundStyle(theme.outdoorFitnessColor(for: level))
                            .frame(width: 20)

                        Text(info.message)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var fitnessBadge: some View {
        let color = theme.outdoorFitnessColor(for: level)
        return Label(level.shortDisplayName, systemImage: level.systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
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

    // MARK: - Computed

    private var temperatureText: String {
        "\(Int(snapshot.temperature))°C"
    }

    private var feelsLikeDiffers: Bool {
        abs(snapshot.temperature - snapshot.feelsLike) >= 3
    }

    private var accessibilityDescription: String {
        var base = String(localized: "Current weather \(snapshot.condition.label), \(Int(snapshot.temperature)) degrees, \(level.displayName)")
        if let locationName = snapshot.locationName {
            base += String(localized: ", \(locationName)")
        }
        guard let info = insightInfo else { return base }
        return base + ". \(info.title): \(info.message)"
    }
}

// MARK: - Placeholder (weather unavailable)

/// Compact card shown when weather data is not available.
/// Tapping triggers location permission request when permission is undetermined.
struct WeatherCardPlaceholder: View {
    var onRequestPermission: (() -> Void)?

    var body: some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "cloud.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)

                Text("Weather")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("Unable to load weather data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel(String(localized: "Weather data unavailable"))
        .onTapGesture {
            onRequestPermission?()
        }
    }
}
