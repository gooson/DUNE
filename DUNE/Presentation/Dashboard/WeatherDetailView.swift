import SwiftUI

/// Detail view for weather information.
/// Shows current conditions, outdoor fitness score, 24h hourly forecast, and 7-day daily forecast.
struct WeatherDetailView: View {
    let snapshot: WeatherSnapshot

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroTemperatureSize: CGFloat = 76
    @State private var heroIsVisible = true

    // MARK: - Cached DateFormatter (Correction #102 + Performance rule: static let cache)

    private enum Cache {
        static let weekdayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()
    }

    /// Pre-computed hour labels (Correction #102: avoid Calendar in body).
    private let hourLabels: [Date: String]
    /// Pre-computed day labels.
    private let dayLabels: [Date: String]
    /// Pre-computed daily temp range (P1: avoid O(N²) recomputation per row).
    private let dailyTempMin: Double
    private let dailyTempMax: Double
    private let hourlyTempMin: Double
    private let hourlyTempMax: Double
    /// Pre-computed best outdoor hour data (P1: avoid 48 score calculations in body).
    private let bestHourData: BestHourInfo?

    struct BestHourInfo {
        let hour: WeatherSnapshot.HourlyWeather
        let score: Int
        let level: OutdoorFitnessLevel
    }

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
        let calendar = Calendar.current

        // Hour labels (weather + air quality hourly dates)
        var hLabels: [Date: String] = [:]
        func addHourLabel(for date: Date) {
            guard hLabels[date] == nil else { return }
            let hour = calendar.component(.hour, from: date)
            if hour == 0 {
                hLabels[date] = String(localized: "Midnight")
            } else if hour == 12 {
                hLabels[date] = String(localized: "Noon")
            } else {
                hLabels[date] = hour < 12 ? "\(hour)AM" : "\(hour - 12)PM"
            }
        }
        for hourly in snapshot.hourlyForecast {
            addHourLabel(for: hourly.hour)
        }
        for aqHourly in snapshot.airQuality?.hourlyForecast ?? [] {
            addHourLabel(for: aqHourly.hour)
        }
        self.hourLabels = hLabels

        // Day labels
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
                dLabels[daily.date] = Cache.weekdayFormatter.string(from: daily.date)
            }
        }
        self.dayLabels = dLabels

        // Daily temperature range (pre-computed once, used by all rows)
        self.dailyTempMin = snapshot.dailyForecast.map(\.temperatureMin).min() ?? 0
        self.dailyTempMax = snapshot.dailyForecast.map(\.temperatureMax).max() ?? 0
        self.hourlyTempMin = snapshot.hourlyForecast.map(\.temperature).min() ?? 0
        self.hourlyTempMax = snapshot.hourlyForecast.map(\.temperature).max() ?? 0

        // Best outdoor hour (pre-computed once, includes air quality)
        if let best = snapshot.bestOutdoorHour {
            let score = WeatherSnapshot.calculateOutdoorScore(
                for: best,
                airQualityHourly: snapshot.airQuality?.hourlyForecast
            )
            self.bestHourData = BestHourInfo(hour: best, score: score, level: OutdoorFitnessLevel(score: score))
        } else {
            self.bestHourData = nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Hero: current weather
                currentWeatherHero

                // Best outdoor hour
                if let data = bestHourData {
                    bestTimeSection(data)
                }

                // Outdoor fitness score
                outdoorFitnessSection

                // Air quality section
                if let aq = snapshot.airQuality {
                    airQualitySection(aq)
                }

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
        .accessibilityIdentifier("weather-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Weather")
    }

    // MARK: - Current Weather Hero

    private var currentWeatherHero: some View {
        ZStack(alignment: .topLeading) {
            WeatherSkyScene(
                condition: snapshot.condition,
                isDaytime: snapshot.isDaytime,
                tint: snapshot.condition.waveColor(for: theme),
                isVisible: heroIsVisible
            )
            .accessibilityHidden(true)

            LinearGradient(
                colors: [.black.opacity(0.62), .black.opacity(0.30), .black.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: snapshot.condition.sfSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)

                Text("\(Int(snapshot.temperature))°C")
                    .font(dynamicTypeSize.isAccessibilitySize
                        ? .largeTitle.weight(.light)
                        : .system(size: heroTemperatureSize, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weather-detail-temperature")

                Text(snapshot.condition.label)
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("weather-detail-condition")

                if let locationName = snapshot.locationName {
                    Label(locationName, systemImage: "location.fill")
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("weather-detail-location")
                }

                if abs(snapshot.temperature - snapshot.feelsLike) >= 3 {
                    Text("Feels like \(Int(snapshot.feelsLike))°C")
                        .font(.subheadline)
                        .accessibilityIdentifier("weather-detail-feels-like")
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
            .padding(dynamicTypeSize.isAccessibilitySize ? DS.Spacing.xl : DS.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 390 : 300)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: sizeClass == .regular ? 780 : .infinity)
        .frame(maxWidth: .infinity)
        .onScrollVisibilityChange(threshold: 0.5) { heroIsVisible = $0 }
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

                    if dynamicTypeSize.isAccessibilitySize {
                        Text("\(score)")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(color)
                            .monospacedDigit()
                    } else {
                        ZStack {
                            Circle()
                                .stroke(color.opacity(0.18), lineWidth: 7)
                            Circle()
                                .trim(from: 0, to: CGFloat(score) / 100)
                                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(score)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(color)
                                .monospacedDigit()
                        }
                        .frame(width: 72, height: 72)
                    }
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

    private func conditionDetailCell(icon: String, label: LocalizedStringKey, value: String, color: Color) -> some View {
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

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [theme.weatherRainColor, theme.accentColor],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 7, height: hourlyTemperatureHeight(for: hour.temperature))
                .frame(height: 38, alignment: .bottom)
                .accessibilityHidden(true)

            Text("\(hour.precipitationProbability)%")
                .font(.caption2)
                .foregroundStyle(theme.weatherRainColor)
                .opacity(hour.precipitationProbability > 0 ? 1 : 0)
                .accessibilityHidden(hour.precipitationProbability == 0)
        }
        .frame(minWidth: 50)
    }

    private func hourlyTemperatureHeight(for temperature: Double) -> CGFloat {
        let range = hourlyTempMax - hourlyTempMin
        guard range > 0 else { return 20 }
        return 10 + 28 * CGFloat((temperature - hourlyTempMin) / range)
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

            // Temperature range bar (uses pre-computed dailyTempMin/Max)
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
        let range = dailyTempMax - dailyTempMin
        let safeMin = Swift.min(min, max)
        let safeMax = Swift.max(min, max)
        let barStart = range > 0 ? (safeMin - dailyTempMin) / range : 0
        let barEnd = range > 0 ? (safeMax - dailyTempMin) / range : 1

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

    private func bestTimeSection(_ data: BestHourInfo) -> some View {
        let color = theme.outdoorFitnessColor(for: data.level)

        return StandardCard {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Best Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(hourLabels[data.hour.hour] ?? data.hour.hour.formatted(date: .omitted, time: .shortened))
                        .font(.headline)
                        .foregroundStyle(theme.accentColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text("\(data.score)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color)
                        .monospacedDigit()

                    Text("\(Int(data.hour.temperature))°C")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Air Quality

    private func airQualitySection(_ aq: AirQualitySnapshot) -> some View {
        let level = aq.overallLevel
        let color = level.color(for: theme)

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader(title: "Air Quality", icon: "aqi.medium")

            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Overall level + badge
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: level.sfSymbol)
                            .font(.title2)
                            .foregroundStyle(color)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(level.displayName)
                                .font(.headline)
                                .foregroundStyle(color)

                            Text("Air Quality")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // US AQI number
                        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                            Text("\(aq.usAQI)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(color)
                                .monospacedDigit()

                            Text("US AQI")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider().opacity(0.3)

                    // PM2.5 / PM10 detail row
                    HStack(spacing: DS.Spacing.lg) {
                        pmDetailItem(
                            label: "PM₂.₅",
                            value: aq.pm2_5,
                            level: aq.pm25Level
                        )

                        pmDetailItem(
                            label: "PM₁₀",
                            value: aq.pm10,
                            level: aq.pm10Level
                        )
                    }

                    // Additional pollutants (if available)
                    if aq.ozone != nil || aq.nitrogenDioxide != nil {
                        Divider().opacity(0.3)

                        HStack(spacing: DS.Spacing.lg) {
                            if let ozone = aq.ozone {
                                pollutantItem(label: "O₃", value: ozone)
                            }
                            if let no2 = aq.nitrogenDioxide {
                                pollutantItem(label: "NO₂", value: no2)
                            }
                            if let so2 = aq.sulphurDioxide {
                                pollutantItem(label: "SO₂", value: so2)
                            }
                        }
                    }
                }
            }

            // Hourly PM2.5 forecast
            if !aq.hourlyForecast.isEmpty {
                StandardCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Hourly PM₂.₅")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.md) {
                                ForEach(aq.hourlyForecast) { hour in
                                    hourlyAQCell(hour)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }
                }
            }
        }
    }

    private func pmDetailItem(label: String, value: Double, level: AirQualityLevel) -> some View {
        let color = level.color(for: theme)
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text("\(Int(value))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()

                Text("μg/m³")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(level.displayName)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pollutantItem(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text("\(Int(value))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.accentColor)
                    .monospacedDigit()

                Text("μg/m³")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hourlyAQCell(_ hour: AirQualitySnapshot.HourlyAirQuality) -> some View {
        let level = AirQualityLevel.fromPM25(hour.pm2_5)
        let color = level.color(for: theme)

        return VStack(spacing: DS.Spacing.xs) {
            Text(hourLabels[hour.hour] ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7)

            Image(systemName: level.sfSymbol)
                .font(.body)
                .foregroundStyle(color)

            Text("\(Int(hour.pm2_5))")
                .font(.callout.weight(.medium))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(minWidth: 50)
    }

    // MARK: - Helpers

    private func sectionHeader(title: LocalizedStringKey, icon: String) -> some View {
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

// Bounded sky art. Motion reads timeline time only in the drawing path and never writes to a weather store.
private struct WeatherSkyScene: View {
    let condition: WeatherConditionType
    let isDaytime: Bool
    let tint: Color
    let isVisible: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.waveReducedMotion) private var reduceMotion

#if DEBUG
    private static let uiAnimationsDisabled = ProcessInfo.processInfo.arguments.contains("--ui-disable-animations")
#else
    private static let uiAnimationsDisabled = false
#endif

    private var shouldAnimate: Bool {
        isVisible && scenePhase == .active && !reduceMotion && !Self.uiAnimationsDisabled
    }

    private var isWet: Bool {
        switch condition {
        case .rain, .heavyRain, .sleet, .thunderstorm: true
        default: false
        }
    }

    private var isSnowing: Bool { condition == .snow || condition == .sleet }
    private var isFoggy: Bool { condition == .fog || condition == .haze }
    private var isWindy: Bool { condition == .wind }
    private var isCloudy: Bool { condition != .clear && condition != .wind }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !shouldAnimate)) { timeline in
            sky(phase: shouldAnimate ? timeline.date.timeIntervalSinceReferenceDate : 0)
        }
    }

    private func sky(phase: TimeInterval) -> some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: isDaytime
                        ? [DS.Color.desertDusk, tint.opacity(0.86), DS.Color.sandMuted]
                        : [DS.Color.weatherNight, DS.Color.desertDusk, tint.opacity(0.44)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [isDaytime ? .white.opacity(0.65 + 0.03 * sin(phase * 0.8)) : .white.opacity(0.27), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 145
                        )
                    )
                    .frame(width: 290, height: 290)
                    .position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.33)

                Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: isDaytime ? 72 : 62, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(isDaytime ? 0.88 : 0.78))
                    .position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.32)

                Canvas { context, size in
                    let drift = CGFloat(sin(phase * 0.22)) * 9
                    let fallCycle = size.height + 60
                    let falling = CGFloat((phase * 12).truncatingRemainder(dividingBy: Double(fallCycle)))
                    func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
                    }
                    if isCloudy {
                        let cloud = Color.white.opacity(isDaytime ? 0.34 : 0.21)
                        ellipse(size.width * 0.49 + drift, size.height * 0.45, size.width * 0.50, 92, cloud)
                        ellipse(size.width * 0.64 - drift * 0.6, size.height * 0.33, size.width * 0.24, 113, cloud)
                        ellipse(size.width * 0.28 + drift * 0.4, size.height * 0.58, size.width * 0.62, 106, cloud.opacity(0.62))
                    }
                    if isWet {
                        var drops = Path()
                        for index in 0..<22 {
                            let x = CGFloat(index) * size.width / 21
                            let baseY = size.height * (0.54 + CGFloat(index % 4) * 0.095)
                            let y = (baseY + falling).truncatingRemainder(dividingBy: fallCycle) - 30
                            drops.move(to: CGPoint(x: x, y: y))
                            drops.addLine(to: CGPoint(x: x - 12, y: y + 28))
                        }
                        context.stroke(drops, with: .color(.white.opacity(condition == .heavyRain ? 0.55 : 0.34)), lineWidth: 2)
                    }
                    if isSnowing {
                        for index in 0..<29 {
                            let x = CGFloat((index * 47) % 97) / 97 * size.width
                            let baseY = CGFloat((index * 29) % 83) / 83 * size.height
                            let y = (baseY + falling * 0.35).truncatingRemainder(dividingBy: fallCycle) - 15
                            ellipse(x + drift * 0.5, y, 3 + CGFloat(index % 3), 3 + CGFloat(index % 3), .white.opacity(0.58))
                        }
                    }
                    if isWindy || isFoggy {
                        var streaks = Path()
                        for index in 0..<7 {
                            let y = size.height * (0.32 + CGFloat(index) * 0.095)
                            streaks.move(to: CGPoint(x: size.width * 0.42 + drift, y: y))
                            streaks.addCurve(
                                to: CGPoint(x: size.width * 1.04, y: y + 8),
                                control1: CGPoint(x: size.width * 0.68, y: y - 19),
                                control2: CGPoint(x: size.width * 0.84, y: y + 23)
                            )
                        }
                        context.stroke(streaks, with: .color(.white.opacity(isFoggy ? 0.32 : 0.56)), lineWidth: isFoggy ? 8 : 2)
                    }
                }
            }
        }
    }
}
