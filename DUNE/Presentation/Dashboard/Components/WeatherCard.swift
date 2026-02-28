import SwiftUI

/// Full-width weather card for the Today tab.
/// Shows current conditions, temperature, humidity, UV, and 6-hour forecast.
struct WeatherCard: View {
    let snapshot: WeatherSnapshot

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

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
                                Text("체감 \(Int(snapshot.feelsLike))°")
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

                // 6-hour forecast
                if !snapshot.hourlyForecast.isEmpty {
                    Divider()
                        .opacity(0.3)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isRegular ? DS.Spacing.xl : DS.Spacing.lg) {
                            ForEach(snapshot.hourlyForecast) { hour in
                                hourCell(hour)
                            }
                        }
                    }
                }

                // Stale indicator
                if snapshot.isStale {
                    Text("날씨 정보가 오래되었습니다")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("현재 날씨 \(snapshot.condition.label), \(Int(snapshot.temperature))도")
    }

    // MARK: - Subviews

    private func hourCell(_ hour: WeatherSnapshot.HourlyWeather) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(hourLabel(hour.hour))
                .font(.caption2)
                .foregroundStyle(.tertiary)

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

    private func hourLabel(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour == 0 { return "자정" }
        if hour == 12 { return "정오" }
        return hour < 12 ? "오전 \(hour)" : "오후 \(hour - 12)"
    }
}
