import SwiftUI

/// 2-column grid of unified personal records (strength + cardio).
struct PersonalRecordsSection: View {
    let records: [ActivityPersonalRecord]
    let notice: String?

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                        ForEach(records.prefix(8)) { record in
                            prCard(record)
                        }
                    }

                    // Chevron hint
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let notice, !notice.isEmpty {
                        Text(notice)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
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
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: record.source == .healthKit ? "apple.logo" : "pencil")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(record.kind.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(primaryValueText(for: record))
                    .font(DS.Typography.cardScore)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if let unit = unitText(for: record) {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

            if let context = contextText(for: record) {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "trophy")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("근력과 유산소 운동을 기록하면 PR을 추적할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

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
            parts.append("심박 \(Int(avg).formattedWithSeparator)bpm")
        }
        if let steps = record.stepCount, steps > 0 {
            parts.append("\(Int(steps).formattedWithSeparator)걸음")
        }

        var weatherParts: [String] = []
        if let condition = record.weatherCondition {
            weatherParts.append(weatherConditionLabel(for: condition))
        }
        if let temp = record.weatherTemperature, temp.isFinite {
            weatherParts.append("\(Int(temp).formattedWithSeparator)°")
        }
        if let humidity = record.weatherHumidity, humidity.isFinite, humidity >= 0 {
            weatherParts.append("습도 \(Int(humidity).formattedWithSeparator)%")
        }
        if let isIndoor = record.isIndoor {
            weatherParts.append(isIndoor ? "실내" : "실외")
        }
        if !weatherParts.isEmpty {
            parts.append(weatherParts.joined(separator: " "))
        }

        guard !parts.isEmpty else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    private func weatherConditionLabel(for rawValue: Int) -> String {
        switch rawValue {
        case 1: return "맑음"
        case 2: return "대체로 맑음"
        case 3, 4, 5: return "흐림"
        case 6, 7: return "안개"
        case 8, 9: return "바람"
        case 12, 18, 20: return "눈"
        case 13, 14, 15, 16, 17, 21, 22, 23: return "비"
        case 24: return "뇌우"
        default: return "날씨"
        }
    }
}
