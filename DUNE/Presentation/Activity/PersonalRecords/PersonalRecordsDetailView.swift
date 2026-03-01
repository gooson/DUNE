import SwiftUI
import Charts

/// Full detail view for unified personal records (strength + cardio).
struct PersonalRecordsDetailView: View {
    let records: [ActivityPersonalRecord]
    let notice: String?

    @State private var viewModel = PersonalRecordsDetailViewModel()
    @State private var selectedKind: ActivityPersonalRecord.Kind?
    @Environment(\.appTheme) private var theme

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    private var recordsUpdateKey: Int {
        var hasher = Hasher()
        for record in records {
            hasher.combine(record.id)
            hasher.combine(record.value)
            hasher.combine(record.date.timeIntervalSince1970)
        }
        return hasher.finalize()
    }

    private var availableKinds: [ActivityPersonalRecord.Kind] {
        let kinds = Set(viewModel.personalRecords.map(\.kind))
        return kinds.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedKindValue: ActivityPersonalRecord.Kind? {
        if let selectedKind, availableKinds.contains(selectedKind) {
            return selectedKind
        }
        return availableKinds.first
    }

    private var filteredRecords: [ActivityPersonalRecord] {
        guard let selectedKind = selectedKindValue else { return [] }
        return viewModel.personalRecords
            .filter { $0.kind == selectedKind }
            .sorted { $0.date > $1.date }
    }

    private var chartRecords: [ActivityPersonalRecord] {
        filteredRecords.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.personalRecords.isEmpty {
                    emptyState
                } else {
                    if let notice, !notice.isEmpty {
                        noticeBanner(notice)
                    }
                    if availableKinds.count > 1 {
                        metricPicker
                    }
                    timelineChart
                    prGrid
                }
            }
            .padding()
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Personal Records")
        .task(id: recordsUpdateKey) {
            viewModel.load(records: records)
            if selectedKindValue == nil {
                selectedKind = availableKinds.first
            }
        }
    }

    // MARK: - Components

    private func noticeBanner(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(DS.Color.textSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var metricPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Metric")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Picker("Metric", selection: Binding(
                get: { selectedKindValue ?? availableKinds.first },
                set: { selectedKind = $0 }
            )) {
                ForEach(availableKinds, id: \.self) { kind in
                    Text(kind.displayName).tag(Optional(kind))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("PR Timeline")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            Chart(chartRecords) { record in
                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Value", record.value)
                )
                .foregroundStyle(record.kind.tintColor)
                .symbolSize(record.isRecent ? 80 : 40)
                .annotation(position: .top, spacing: 4) {
                    if record.isRecent {
                        Text(record.title)
                            .font(.system(size: 8))
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                        .foregroundStyle(theme.accentColor.opacity(0.30))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(theme.sandColor)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(theme.accentColor.opacity(0.30))
                    AxisValueLabel {
                        if let v = value.as(Double.self), let selectedKind = selectedKindValue {
                            Text(chartAxisValue(v, for: selectedKind))
                                .foregroundStyle(theme.sandColor)
                        }
                    }
                }
            }
            .frame(height: 220)
            .clipped()
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var prGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let selectedKind = selectedKindValue {
                Text(selectedKind.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(filteredRecords) { record in
                    prCard(record)
                }
            }
        }
    }

    private func prCard(_ record: ActivityPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: record.kind.iconName)
                    .font(.caption2)
                    .foregroundStyle(record.kind.tintColor)
                Text(record.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if record.isRecent {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DS.Color.activity, in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(primaryValueText(for: record))
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if let unit = unitText(for: record) {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            if let context = contextText(for: record) {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(1)
            }

            Text(record.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No personal records yet.")
                .font(.headline)
                .foregroundStyle(DS.Color.textSecondary)
            Text("Build your workout history to track both strength and cardio PRs.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    // MARK: - Formatting

    private func primaryValueText(for record: ActivityPersonalRecord) -> String {
        switch record.kind {
        case .strengthWeight:
            return record.value.formattedWithSeparator()
        case .fastestPace:
            let totalSeconds = Int(record.value)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)'\(String(format: "%02d", seconds))\""
        case .longestDistance:
            let km = record.value / 1000.0
            return km.formattedWithSeparator(fractionDigits: km >= 10 ? 1 : 2)
        case .highestCalories:
            return record.value.formattedWithSeparator()
        case .longestDuration:
            return TimeInterval(record.value).formattedDuration()
        case .highestElevation:
            return record.value.formattedWithSeparator()
        }
    }

    private func chartAxisValue(_ value: Double, for kind: ActivityPersonalRecord.Kind) -> String {
        switch kind {
        case .fastestPace:
            let totalSeconds = Int(value)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)'\(String(format: "%02d", seconds))\""
        case .longestDistance:
            return (value / 1000.0).formattedWithSeparator(fractionDigits: 1)
        case .longestDuration:
            return TimeInterval(value).formattedDuration()
        default:
            return value.formattedWithSeparator()
        }
    }

    private func unitText(for record: ActivityPersonalRecord) -> String? {
        switch record.kind {
        case .strengthWeight: "kg"
        case .fastestPace: "/km"
        case .longestDistance: "km"
        case .highestCalories: "kcal"
        case .longestDuration: nil
        case .highestElevation: "m"
        }
    }

    private func contextText(for record: ActivityPersonalRecord) -> String? {
        var parts: [String] = []
        if let avg = record.heartRateAvg, avg > 0 {
            parts.append("HR \(Int(avg).formattedWithSeparator)bpm")
        }
        if let steps = record.stepCount, steps > 0 {
            parts.append("\(Int(steps).formattedWithSeparator) steps")
        }

        var weatherParts: [String] = []
        if let condition = record.weatherCondition {
            weatherParts.append(weatherConditionLabel(for: condition))
        }
        if let temp = record.weatherTemperature, temp.isFinite {
            weatherParts.append("\(Int(temp).formattedWithSeparator)°")
        }
        if let humidity = record.weatherHumidity, humidity.isFinite, humidity >= 0 {
            weatherParts.append("Humidity \(Int(humidity).formattedWithSeparator)%")
        }
        if let isIndoor = record.isIndoor {
            weatherParts.append(isIndoor ? "Indoor" : "Outdoor")
        }
        if !weatherParts.isEmpty {
            parts.append(weatherParts.joined(separator: " "))
        }

        guard !parts.isEmpty else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    private func weatherConditionLabel(for rawValue: Int) -> String {
        switch rawValue {
        case 1: return "Clear"
        case 2: return "Mostly Clear"
        case 3, 4, 5: return "Cloudy"
        case 6, 7: return "Foggy"
        case 8, 9: return "Windy"
        case 12, 18, 20: return "Snow"
        case 13, 14, 15, 16, 17, 21, 22, 23: return "Rain"
        case 24: return "Thunderstorm"
        default: return "Weather"
        }
    }
}
