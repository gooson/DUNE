import SwiftUI

/// Detail view for weather information.
/// Shows current conditions, outdoor fitness score, 24h hourly forecast, and 7-day daily forecast.
struct WeatherDetailView: View {
    let snapshot: WeatherSnapshot

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Pre-computed hour labels (Correction #102: avoid Calendar in body).
    private let hourLabels: [Date: String]
    /// Pre-computed day labels.
    private let dayLabels: [Date: String]

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
        var hLabels: [Date: String] = [:]
        let calendar = Calendar.current
        for hourly in snapshot.hourlyForecast {
            let hour = calendar.component(.hour, from: hourly.hour)
            if hour == 0 {
                hLabels[hourly.hour] = String(localized: "Midnight")
            } else if hour == 12 {
                hLabels[hourly.hour] = String(localized: "Noon")
            } else {
                hLabels[hourly.hour] = hour < 12 ? "\(hour)AM" : "\(hour - 12)PM"
            }
        }
        self.hourLabels = hLabels

        var dLabels: [Date: String] = [:]
        let today = calendar.startOfDay(for: Date())
        for daily in snapshot.dailyForecast {
            let dayStart = calendar.startOfDay(for: daily.date)
            if calendar.isDate(dayStart, inSameDayAs: today) {
                dLabels[daily.date] = String(localized: "Today")
            } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                      calendar.isDate(dayStart, inSameDayAs: tomorrow) {
                dLabels[daily.date] = String(localized: "Tomorrow")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                dLabels[daily.date] = formatter.string(from: daily.date)
            }
        }
        self.dayLabels = dLabels
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Hero: current weather
                currentWeatherHero

                // Outdoor fitness score
                outdoorFitnessSection

                // Condition details grid
                conditionDetailsGrid

                // 24-hour forecast
                if !snapshot.hourlyForecast.isEmpty {
                    hourlyForecastSection
                }

                // 7-day forecast
                if !snapshot.dailyForecast.isEmpty {
                    dailyForecastSection
                }

                // Best outdoor hour
                if let bestHour = snapshot.bestOutdoorHour {
                    bestTimeSection(bestHour)
                }

                // Stale indicator
                if snapshot.isStale {
                    Text("Weather data is outdated")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Weather")
    }

    // MARK: - Current Weather Hero

    private var currentWeatherHero: some View {
        StandardCard {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: snapshot.condition.sfSymbol)
                    .font(.system(size: 48))
                    .foregroundStyle(snapshot.condition.iconColor(for: theme))
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("\(Int(snapshot.temperature))°C")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(theme.heroTextGradient)
                        .monospacedDigit()

                    Text(snapshot.condition.label)
                        .font(.title3)
                        .foregroundStyle(theme.sandColor)

                    if abs(snapshot.temperature - snapshot.feelsLike) >= 3 {
                        Text("Feels like \(Int(snapshot.feelsLike))°C")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Outdoor Fitness Score

    private var outdoorFitnessSection: some View {
        let level = snapshot.outdoorFitnessLevel
        let score = snapshot.outdoorFitnessScore
        let color = theme.outdoorFitnessColor(for: level)

        return StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: level.systemImage)
                        .font(.title2)
                        .foregroundStyle(color)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(level.displayName)
                            .font(.headline)
                            .foregroundStyle(color)

                        Text("Outdoor Fitness Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                }

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(DS.Opacity.subtle))
                            .frame(height: 8)

                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(score) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    // MARK: - Condition Details Grid

    private var conditionDetailsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: DS.Spacing.md),
            GridItem(.flexible(), spacing: DS.Spacing.md)
        ]

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            conditionDetailCell(
                icon: "humidity.fill",
                label: "Humidity",
                value: "\(Int(snapshot.humidity * 100))%",
                color: theme.weatherRainColor
            )
            conditionDetailCell(
                icon: "sun.max.fill",
                label: "UV Index",
                value: "\(snapshot.uvIndex)",
                color: uvColor
            )
            conditionDetailCell(
                icon: "wind",
                label: "Wind",
                value: "\(Int(snapshot.windSpeed)) km/h",
                color: theme.weatherWindColor
            )
            conditionDetailCell(
                icon: "thermometer.medium",
                label: "Feels Like",
                value: "\(Int(snapshot.feelsLike))°C",
                color: theme.accentColor
            )
        }
    }

    private func conditionDetailCell(icon: String, label: String, value: String, color: Color) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.accentColor)
                    .monospacedDigit()

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Hourly Forecast

    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader(title: "Hourly Forecast", icon: "clock")

            StandardCard {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(snapshot.hourlyForecast) { hour in
                            hourlyCell(hour)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xxs)
                }
            }
        }
    }

    private func hourlyCell(_ hour: WeatherSnapshot.HourlyWeather) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(hourLabels[hour.hour] ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7)

            Image(systemName: hour.condition.sfSymbol)
                .font(.body)
                .foregroundStyle(hour.condition.iconColor(for: theme))
                .symbolRenderingMode(.multicolor)

            Text("\(Int(hour.temperature))°")
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.accentColor)
                .monospacedDigit()

            if hour.precipitationProbability > 0 {
                Text("\(hour.precipitationProbability)%")
                    .font(.caption2)
                    .foregroundStyle(theme.weatherRainColor)
            }
        }
        .frame(minWidth: 50)
    }

    // MARK: - Daily Forecast

    private var dailyForecastSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader(title: "7-Day Forecast", icon: "calendar")

            StandardCard {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(snapshot.dailyForecast) { day in
                        dailyRow(day)

                        if day.id != snapshot.dailyForecast.last?.id {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    private func dailyRow(_ day: WeatherSnapshot.DailyForecast) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(dayLabels[day.date] ?? "")
                .font(.subheadline)
                .frame(width: 56, alignment: .leading)

            Image(systemName: day.condition.sfSymbol)
                .font(.body)
                .foregroundStyle(day.condition.iconColor(for: theme))
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)

            if day.precipitationProbabilityMax > 0 {
                Text("\(day.precipitationProbabilityMax)%")
                    .font(.caption)
                    .foregroundStyle(theme.weatherRainColor)
                    .frame(width: 32)
            } else {
                Color.clear.frame(width: 32)
            }

            // Temperature range bar
            temperatureBar(min: day.temperatureMin, max: day.temperatureMax)

            Text("\(Int(day.temperatureMin))°")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)

            Text("\(Int(day.temperatureMax))°")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.accentColor)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func temperatureBar(min: Double, max: Double) -> some View {
        let allMin = snapshot.dailyForecast.map(\.temperatureMin).min() ?? min
        let allMax = snapshot.dailyForecast.map(\.temperatureMax).max() ?? max
        let range = allMax - allMin
        let barStart = range > 0 ? (min - allMin) / range : 0
        let barEnd = range > 0 ? (max - allMin) / range : 1

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.accentColor.opacity(DS.Opacity.subtle))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.duskColor, theme.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: Swift.max(4, geo.size.width * CGFloat(barEnd - barStart)))
                    .offset(x: geo.size.width * CGFloat(barStart))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Best Time

    private func bestTimeSection(_ bestHour: WeatherSnapshot.HourlyWeather) -> some View {
        let score = WeatherSnapshot.calculateOutdoorScore(for: bestHour)
        let level = OutdoorFitnessLevel(score: score)
        let color = theme.outdoorFitnessColor(for: level)

        return StandardCard {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Best Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(hourLabels[bestHour.hour] ?? bestHour.hour.formatted(date: .omitted, time: .shortened))
                        .font(.headline)
                        .foregroundStyle(theme.accentColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text("\(score)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color)
                        .monospacedDigit()

                    Text("\(Int(bestHour.temperature))°C")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(theme.accentColor)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    private var uvColor: Color {
        switch snapshot.uvIndex {
        case 0...2: .secondary
        case 3...5: theme.accentColor
        case 6...7: DS.Color.caution
        default:    DS.Color.negative
        }
    }
}
