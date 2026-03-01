import SwiftUI

/// Full-width weather card for the Today tab.
/// Shows current conditions, temperature, and outdoor fitness badge.
/// Tapping navigates to WeatherDetailView.
struct WeatherCard: View {
    let snapshot: WeatherSnapshot

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        InlineCard {
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
                fitnessBadge

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var fitnessBadge: some View {
        let level = snapshot.outdoorFitnessLevel
        return Label(level.shortDisplayName, systemImage: level.systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.outdoorFitnessColor(for: level))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background {
                Capsule()
                    .fill(theme.outdoorFitnessColor(for: level).opacity(DS.Opacity.subtle))
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
        "Current weather \(snapshot.condition.label), \(Int(snapshot.temperature)) degrees, \(snapshot.outdoorFitnessLevel.displayName)"
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
        .accessibilityLabel("Weather data unavailable")
        .onTapGesture {
            onRequestPermission?()
        }
    }
}
