import SwiftUI
import SwiftData

/// Detail view for a single exercise session, showing set data + HealthKit heart rate chart.
struct ExerciseSessionDetailView: View {
    let record: ExerciseRecord
    var activityType: WorkoutActivityType = .other
    var displayName: String?
    var equipment: Equipment?
    var showHistoryLink: Bool = true

    /// Resolved title: explicit displayName → record.exerciseType fallback
    private var resolvedTitle: String {
        if let name = displayName, !name.isEmpty { return name }
        return record.exerciseType
    }

    @Environment(\.appTheme) private var theme
    @State private var heartRateSummary: HeartRateSummary?
    @State private var isLoadingHR = false
    @State private var hrError: String?
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue

    private let heartRateService = HeartRateQueryService(manager: .shared)

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                sessionHeader
                cardioMetricsSection
                healthKitBadge
                setsList
                heartRateSection
                calorieSection
                viewHistoryLink
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle(record.exerciseType)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadHeartRate()
        }
    }

    // MARK: - Header

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Group {
                    if let equipment {
                        equipment.svgIcon(size: 28)
                    } else {
                        Image(systemName: activityType.iconName)
                            .font(.system(size: 28))
                            .frame(width: 28, height: 28)
                    }
                }
                .foregroundStyle(activityType.color)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(resolvedTitle)
                        .font(.title2.weight(.semibold))
                    Text(record.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(record.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            if record.duration > 0 || record.bestCalories != nil {
                HStack(spacing: DS.Spacing.xl) {
                    if record.duration > 0 {
                        VStack {
                            Text(formattedDuration(record.duration))
                                .font(.title3.weight(.semibold).monospacedDigit())
                            Text("Duration")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    if let cal = record.bestCalories, cal > 0, cal < 5000 {
                        VStack {
                            Text(Int(cal).formattedWithSeparator)
                                .font(.title3.weight(.semibold).monospacedDigit())
                            Text("kcal")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - HealthKit Badge

    private var hasCardioMetrics: Bool {
        (record.distance ?? 0) > 0
            || (record.stepCount ?? 0) > 0
            || (record.averagePaceSecondsPerKm ?? 0) > 0
            || (record.averageCadenceStepsPerMinute ?? 0) > 0
            || (record.elevationGainMeters ?? 0) > 0
            || (record.floorsAscended ?? 0) > 0
    }

    @ViewBuilder
    private var cardioMetricsSection: some View {
        if hasCardioMetrics {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Cardio Metrics", systemImage: "figure.run")
                    .font(.headline)
                    .foregroundStyle(theme.sandColor)

                HStack(spacing: DS.Spacing.sm) {
                    if let distanceKm = normalizedDistanceKm(record.distance) {
                        cardioMetricCard(
                            title: "Distance",
                            value: String(format: "%.2f km", distanceKm),
                            icon: "location.fill"
                        )
                    }

                    if let steps = record.stepCount, steps > 0 {
                        cardioMetricCard(
                            title: "Steps",
                            value: steps.formattedWithSeparator,
                            icon: "figure.walk"
                        )
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    if let pace = record.averagePaceSecondsPerKm, pace > 0 {
                        cardioMetricCard(
                            title: "Avg Pace",
                            value: "\(formattedPace(pace)) /km",
                            icon: "speedometer"
                        )
                    }

                    if let cadence = record.averageCadenceStepsPerMinute, cadence > 0 {
                        cardioMetricCard(
                            title: "Cadence",
                            value: "\(Int(cadence).formattedWithSeparator) spm",
                            icon: "gauge.with.dots.needle.50percent"
                        )
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    if let elevation = record.elevationGainMeters, elevation > 0 {
                        cardioMetricCard(
                            title: "Elevation Gain",
                            value: "\(Int(elevation).formattedWithSeparator) m",
                            icon: "mountain.2.fill"
                        )
                    } else if let floors = record.floorsAscended, floors > 0 {
                        cardioMetricCard(
                            title: "Floors",
                            value: "\(Int(floors).formattedWithSeparator)",
                            icon: "figure.stair.stepper"
                        )
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    private func cardioMetricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    @ViewBuilder
    private var healthKitBadge: some View {
        if hasHealthKitLink {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text("Linked to Apple Health")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(.red.opacity(DS.Opacity.light), in: Capsule())
        }
    }

    // MARK: - Sets

    private var setsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Sets")
                .font(.headline)

            let sets = record.completedSets
            if sets.isEmpty {
                Text("No set data recorded")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            } else {
                ForEach(sets, id: \.id) { workoutSet in
                    setRow(workoutSet)
                }
            }
        }
    }

    private func setRow(_ workoutSet: WorkoutSet) -> some View {
        HStack {
            Text("Set \(workoutSet.setNumber)")
                .font(.subheadline.weight(.medium))

            Spacer()

            HStack(spacing: DS.Spacing.md) {
                if let weight = workoutSet.weight {
                    Text("\(formattedWeight(weight)) \(weightUnit.displayName)")
                        .font(.subheadline.monospacedDigit())
                }
                if let reps = workoutSet.reps {
                    Text("\(reps.formattedWithSeparator) reps")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Heart Rate

    private var hasHealthKitLink: Bool {
        guard let id = record.healthKitWorkoutID else { return false }
        return !id.isEmpty
    }

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Heart Rate", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(theme.sandColor)

            if !hasHealthKitLink {
                placeholderView(
                    icon: "heart.slash",
                    title: "Not linked to Apple Health",
                    subtitle: "Wear Apple Watch during workout to record heart rate"
                )
            } else if isLoadingHR {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let summary = heartRateSummary, !summary.isEmpty {
                HeartRateChartView(
                    samples: summary.samples,
                    averageBPM: summary.average,
                    maxBPM: summary.max
                )
            } else if let error = hrError {
                placeholderView(icon: "exclamationmark.triangle", title: error)
            } else {
                placeholderView(icon: "waveform.path.ecg", title: "No heart rate data available")
            }
        }
        .padding(DS.Spacing.md)
        .chartSurface(cornerRadius: DS.Radius.md, topBloomHeight: 34)
    }

    /// Reusable placeholder view for empty/error states in the heart rate section.
    private func placeholderView(icon: String, title: String, subtitle: String? = nil) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    // MARK: - Calories

    private var calorieSection: some View {
        Group {
            if let calories = record.bestCalories, calories > 0, calories < 5000 {
                HStack {
                    Label("Calories", systemImage: "flame.fill")
                        .font(.subheadline)
                    Spacer()
                    Text("\(calories, specifier: "%.1f") kcal")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(DS.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }

    // MARK: - View History Link

    @ViewBuilder
    private var viewHistoryLink: some View {
        if showHistoryLink, let defID = record.exerciseDefinitionID, !defID.isEmpty {
            NavigationLink {
                ExerciseHistoryView(
                    exerciseDefinitionID: defID,
                    exerciseName: record.exerciseType
                )
            } label: {
                HStack {
                    Label("View All Sessions", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data Loading

    private func loadHeartRate() async {
        guard hasHealthKitLink,
              let workoutID = record.healthKitWorkoutID else { return }

        isLoadingHR = true

        do {
            let summary = try await heartRateService.fetchHeartRateSummary(forWorkoutID: workoutID)
            guard !Task.isCancelled else {
                isLoadingHR = false
                return
            }
            heartRateSummary = summary
        } catch {
            guard !Task.isCancelled else {
                isLoadingHR = false
                return
            }
            hrError = String(localized: "Could not load heart rate data")
        }
        isLoadingHR = false
    }

    // MARK: - Formatting

    private func formattedWeight(_ kg: Double) -> String {
        weightUnit.fromKg(kg).formatted(.number.precision(.fractionLength(0...1)))
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return String(localized: "\(hours)h \(mins)min")
        }
        return String(localized: "\(totalMinutes)min")
    }

    private func formattedPace(_ pace: Double) -> String {
        guard pace > 0, pace.isFinite, pace < 3600 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Legacy records can contain either km or meters. Keep the same heuristic used in ActivityViewModel.
    private func normalizedDistanceKm(_ rawDistance: Double?) -> Double? {
        guard let distance = rawDistance, distance > 0, distance.isFinite else { return nil }
        if distance <= 500 {
            return distance
        }
        return distance / 1000.0
    }
}
