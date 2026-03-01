import SwiftUI

/// Full-width weather card for the Today tab.
/// Shows current conditions, temperature, outdoor fitness badge, and optional coaching insight.
/// Tapping navigates to WeatherDetailView.
struct WeatherCard: View {
    let snapshot: WeatherSnapshot
    let weatherInsight: CoachingInsight?

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(snapshot: WeatherSnapshot, weatherInsight: CoachingInsight? = nil) {
        self.snapshot = snapshot
        self.weatherInsight = weatherInsight
    }

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        let level = snapshot.outdoorFitnessLevel

        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    // Weather icon
                    Image(systemName: snapshot.condition.sfSymbol)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(snapshot.condition.iconColor(for: theme))
                        .symbolRenderingMode(.multicolor)

                    // Temperature + condition
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

                        Text(snapshot.condition.label)
                            .font(.subheadline)
                            .foregroundStyle(theme.sandColor)
                    }

                    Spacer()

                    // Outdoor fitness badge
                    fitnessBadge(level: level)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                // Coaching insight (weather-category only)
                if let insight = weatherInsight {
                    Divider().opacity(0.3)

                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: insight.iconName)
                            .font(.subheadline)
                            .foregroundStyle(theme.outdoorFitnessColor(for: level))
                            .frame(width: 20)

                        Text(insight.message)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription(level: level))
    }

    // MARK: - Subviews

    private func fitnessBadge(level: OutdoorFitnessLevel) -> some View {
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

    // MARK: - Computed

    private var temperatureText: String {
        "\(Int(snapshot.temperature))°C"
    }

    private var feelsLikeDiffers: Bool {
        abs(snapshot.temperature - snapshot.feelsLike) >= 3
    }

    private func accessibilityDescription(level: OutdoorFitnessLevel) -> String {
        if let insight = weatherInsight {
            return String(localized: "Current weather \(snapshot.condition.label), \(Int(snapshot.temperature)) degrees, \(level.displayName). \(insight.message)")
        }
        return String(localized: "Current weather \(snapshot.condition.label), \(Int(snapshot.temperature)) degrees, \(level.displayName)")
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
