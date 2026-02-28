import SwiftUI

/// Full-width weather card for the Today tab.
/// Shows current conditions, temperature, humidity, UV, and 6-hour forecast.
struct WeatherCard: View {
    let snapshot: WeatherSnapshot

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    /// Pre-computed hour labels (Correction #102: avoid Calendar in body).
    private let hourLabels: [Date: String]

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
        var labels: [Date: String] = [:]
        let calendar = Calendar.current
        for hourly in snapshot.hourlyForecast {
            let hour = calendar.component(.hour, from: hourly.hour)
            if hour == 0 {
                labels[hourly.hour] = String(localized: "Midnight")
            } else if hour == 12 {
                labels[hourly.hour] = String(localized: "Noon")
            } else {
                labels[hourly.hour] = hour < 12 ? "\(hour)AM" : "\(hour - 12)PM"
            }
        }
        self.hourLabels = labels
    }

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Current conditions row
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: snapshot.condition.sfSymbol)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(snapshot.condition.iconColor)
                        .symbolRenderingMode(.multicolor)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(temperatureText)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()

                            if feelsLikeDiffers {
                                Text("Feels \(Int(snapshot.feelsLike))°")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(snapshot.condition.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Humidity + UV badges
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Label("\(Int(snapshot.humidity * 100))%", systemImage: "humidity.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("UV \(snapshot.uvIndex)", systemImage: "sun.max.fill")
                            .font(.caption)
                            .foregroundStyle(uvColor)
                    }
                }

                // 6-hour forecast (evenly distributed)
                if snapshot.hourlyForecast.count >= 3 {
                    Divider()
                        .opacity(0.3)

                    HStack(spacing: 0) {
                        ForEach(snapshot.hourlyForecast.prefix(6)) { hour in
                            hourCell(hour)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Stale indicator
                if snapshot.isStale {
                    Text("Weather data is outdated")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current weather \(snapshot.condition.label), \(Int(snapshot.temperature)) degrees")
    }

    // MARK: - Subviews

    private func hourCell(_ hour: WeatherSnapshot.HourlyWeather) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(hourLabels[hour.hour] ?? "")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .minimumScaleFactor(0.7)

            Image(systemName: hour.condition.sfSymbol)
                .font(.caption)
                .foregroundStyle(hour.condition.iconColor)
                .symbolRenderingMode(.multicolor)

            Text("\(Int(hour.temperature))°")
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
    }

    // MARK: - Computed

    private var temperatureText: String {
        "\(Int(snapshot.temperature))°C"
    }

    private var feelsLikeDiffers: Bool {
        abs(snapshot.temperature - snapshot.feelsLike) >= 3
    }

    private var uvColor: Color {
        switch snapshot.uvIndex {
        case 0...2: .secondary
        case 3...5: DS.Color.warmGlow
        case 6...7: DS.Color.caution
        default:    DS.Color.negative
        }
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
