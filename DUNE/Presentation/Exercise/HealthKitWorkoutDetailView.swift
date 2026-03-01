import SwiftUI

/// Detail view for a HealthKit-only workout (not created by this app).
/// Shows rich data: HR chart, pace, elevation, weather, badges.
struct HealthKitWorkoutDetailView: View {
    let workout: WorkoutSummary

    @Environment(\.appTheme) private var theme
    @State private var viewModel = HealthKitWorkoutDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                workoutHeader
                badgesSection
                statsGrid
                heartRateSection
                weatherSection
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .background { DetailWaveBackground() }
        .navigationTitle(workout.activityType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadDetail(workoutID: workout.id)
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: workout.activityType.iconName)
                    .font(.title)
                    .foregroundStyle(workout.activityType.color)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(workout.activityType.displayName)
                        .font(.title2.weight(.semibold))

                    Text(workout.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)

                    Text(workout.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            HStack(spacing: DS.Spacing.xl) {
                statItem(
                    value: formattedDuration(workout.duration),
                    label: "Duration"
                )
                if let cal = workout.calories, cal > 0 {
                    statItem(
                        value: Int(cal).formattedWithSeparator,
                        label: "kcal"
                    )
                }
                if let dist = workout.distance, dist > 0 {
                    statItem(
                        value: formattedDistance(dist),
                        label: "km"
                    )
                }
            }
            .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Badges

    @ViewBuilder
    private var badgesSection: some View {
        let hasMilestone = workout.milestoneDistance != nil
        let hasPR = workout.isPersonalRecord

        if hasMilestone || hasPR {
            HStack(spacing: DS.Spacing.sm) {
                if let milestone = workout.milestoneDistance {
                    WorkoutBadgeView.milestone(milestone)
                }
                if hasPR {
                    ForEach(workout.personalRecordTypes, id: \.self) { prType in
                        WorkoutBadgeView.personalRecord(prType)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm),
        ], spacing: DS.Spacing.sm) {
            // Heart rate avg
            if let hrAvg = workout.heartRateAvg {
                statCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Avg Heart Rate",
                    value: Int(hrAvg).formattedWithSeparator,
                    unit: "bpm"
                )
            }
            // Heart rate max
            if let hrMax = workout.heartRateMax {
                statCard(
                    icon: "heart.fill",
                    iconColor: .red.opacity(0.7),
                    title: "Max Heart Rate",
                    value: Int(hrMax).formattedWithSeparator,
                    unit: "bpm"
                )
            }
            // Pace
            if let pace = workout.averagePace {
                statCard(
                    icon: "speedometer",
                    iconColor: DS.Color.activity,
                    title: "Avg Pace",
                    value: formattedPace(pace),
                    unit: "/km"
                )
            }
            // Elevation
            if let elevation = workout.elevationAscended, elevation > 0 {
                statCard(
                    icon: "mountain.2.fill",
                    iconColor: .green,
                    title: "Elevation Gain",
                    value: Int(elevation).formattedWithSeparator,
                    unit: "m"
                )
            }
            // Step count
            if let steps = workout.stepCount, steps > 0 {
                statCard(
                    icon: "figure.walk",
                    iconColor: DS.Color.steps,
                    title: "Steps",
                    value: Int(steps).formattedWithSeparator,
                    unit: "steps"
                )
            }
            // Effort score
            if let effort = viewModel.effortScore ?? workout.effortScore {
                statCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: "Effort",
                    value: effort.formattedWithSeparator(fractionDigits: 1),
                    unit: "/10"
                )
            }
            // Indoor/Outdoor
            if let isIndoor = workout.isIndoor {
                statCard(
                    icon: isIndoor ? "building.fill" : "sun.max.fill",
                    iconColor: isIndoor ? .gray : .yellow,
                    title: "Environment",
                    value: isIndoor ? String(localized: "Indoor") : String(localized: "Outdoor"),
                    unit: ""
                )
            }
        }
    }

    private func statCard(icon: String, iconColor: Color, title: LocalizedStringKey, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Heart Rate Chart

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Heart Rate", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(theme.sandColor)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let summary = viewModel.heartRateSummary, !summary.isEmpty {
                HeartRateChartView(
                    samples: summary.samples,
                    averageBPM: summary.average,
                    maxBPM: summary.max
                )
            } else {
                placeholderView(
                    icon: "waveform.path.ecg",
                    title: "No heart rate data"
                )
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Weather

    @ViewBuilder
    private var weatherSection: some View {
        if workout.weatherTemperature != nil || workout.weatherCondition != nil {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Weather", systemImage: "cloud.sun.fill")
                    .font(.headline)

                HStack(spacing: DS.Spacing.xl) {
                    if let temp = workout.weatherTemperature {
                        VStack(spacing: DS.Spacing.xxs) {
                            Text("\(Int(temp).formattedWithSeparator)°")
                                .font(.title2.weight(.semibold).monospacedDigit())
                            Text("Temp")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    if let condition = workout.weatherCondition {
                        VStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: weatherIcon(for: condition))
                                .font(.title2)
                            Text("Condition")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    if let humidity = workout.weatherHumidity {
                        VStack(spacing: DS.Spacing.xxs) {
                            Text("\(Int(humidity).formattedWithSeparator)%")
                                .font(.title2.weight(.semibold).monospacedDigit())
                            Text("Humidity")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    // MARK: - Helpers

    private func placeholderView(icon: String, title: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours):\(String(format: "%02d", mins))"
        }
        return totalMinutes.formattedWithSeparator
    }

    private func formattedDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        if km >= 10 {
            return km.formattedWithSeparator(fractionDigits: 1)
        }
        return km.formattedWithSeparator(fractionDigits: 2)
    }

    private func formattedPace(_ secPerKm: Double) -> String {
        let totalSeconds = Int(secPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)'\(String(format: "%02d", seconds))\""
    }

    /// Maps HKWeatherCondition rawValue to SF Symbol.
    private func weatherIcon(for conditionRaw: Int) -> String {
        switch conditionRaw {
        case 1: "sun.max.fill"           // clear
        case 2: "sun.min.fill"           // fair
        case 3: "cloud.sun.fill"         // partlyCloudy
        case 4: "cloud.fill"             // mostlyCloudy
        case 5: "smoke.fill"             // cloudy
        case 6: "cloud.fog.fill"         // foggy
        case 7: "sun.haze.fill"          // haze
        case 8: "wind"                   // windy
        case 9: "wind"                   // blustery
        case 10: "aqi.medium"            // smoky
        case 11: "aqi.low"              // dust
        case 12: "cloud.snow.fill"       // snow
        case 13: "cloud.hail.fill"       // hail
        case 14: "cloud.sleet.fill"      // sleet
        case 15: "cloud.drizzle.fill"    // freezingDrizzle
        case 16: "cloud.rain.fill"       // freezingRain
        case 17: "cloud.hail.fill"       // mixedRainAndHail
        case 18: "cloud.snow.fill"       // mixedRainAndSnow
        case 19: "cloud.sleet.fill"      // mixedRainAndSleet
        case 20: "cloud.snow.fill"       // mixedSnowAndSleet
        case 21: "cloud.drizzle.fill"    // drizzle
        case 22: "cloud.rain.fill"       // scatteredShowers
        case 23: "cloud.heavyrain.fill"  // showers
        case 24: "cloud.bolt.rain.fill"  // thunderstorms
        case 25: "tropicalstorm"         // tropicalStorm
        case 26: "hurricane"             // hurricane
        case 27: "tornado"               // tornado
        default: "cloud.fill"
        }
    }
}
