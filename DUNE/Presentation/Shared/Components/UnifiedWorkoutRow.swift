import SwiftUI

/// Unified workout row used in both Train (compact) and Exercise (full) tabs.
/// Single source of truth for workout list item rendering.
struct UnifiedWorkoutRow: View {
    let item: ExerciseListItem
    let style: Style
    let rewardEvents: [WorkoutRewardEvent]

    init(item: ExerciseListItem, style: Style, rewardEvents: [WorkoutRewardEvent] = []) {
        self.item = item
        self.style = style
        self.rewardEvents = rewardEvents
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var muscleBadgeFontSize: CGFloat = 9

    private var compactRewardBadges: [WorkoutAchievementBadge.Model] {
        var seenLabels: Set<String> = []
        var badges = rewardEvents
            .compactMap(WorkoutAchievementBadge.Model.init(event:))
            .filter { seenLabels.insert("\($0.isRecord)-\($0.text)").inserted }
        if let milestone = item.milestoneDistance,
           !rewardEvents.contains(where: { $0.kind == .milestone && $0.detail == milestone.label }) {
            badges.append(.init(id: "distance-\(milestone.rawValue)", text: milestone.label, isRecord: false))
        }
        if item.isPersonalRecord && !rewardEvents.contains(where: { $0.kind == .personalRecord }) {
            badges.append(.init(id: "pr-\(item.id)", text: String(localized: "PR"), isRecord: true))
        }
        return badges
    }

    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
    }

    enum Style {
        /// Train dashboard — InlineCard, compact info, weekday+time date
        case compact
        /// Exercise tab — plain row, full metrics, date-only
        case full
    }

    var body: some View {
        switch style {
        case .compact:
            InlineCard { compactContent }
                .prHighlight(compactRewardBadges.contains { $0.isRecord })
        case .full:
            fullContent
        }
    }

    // MARK: - Compact (Train Dashboard)

    private var compactContent: some View {
        rowLayout {
            activityIcon(size: 28, font: .body)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                titleRow

                HStack(spacing: DS.Spacing.sm) {
                    Text(item.date, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)

                    if let hrAvg = item.validHeartRateAvg {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                            Text(hrAvg.formattedWithSeparator)
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.Color.heartRate)
                        .accessibilityLabel(Text("Average heart rate: \(hrAvg) bpm"))
                    }
                }

                if !compactRewardBadges.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: DS.Spacing.xs) {
                            ForEach(compactRewardBadges) { badge in
                                WorkoutAchievementBadge(model: badge)
                            }
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(compactRewardBadges) { badge in
                                WorkoutAchievementBadge(model: badge)
                            }
                        }
                    }
                }

                if let summary = item.setSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                muscleBadges
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            compactTrailing
        }
    }

    // MARK: - Full (Exercise Tab)

    private var fullContent: some View {
        rowLayout {
            activityIcon(size: 32, font: .title3)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                titleRow

                if let secondaryName = item.secondaryDisplayName {
                    Text(secondaryName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                metricsRow

                if item.milestoneDistance != nil || item.isPersonalRecord {
                    WorkoutBadgeView.inlineBadge(
                        milestone: item.milestoneDistance,
                        isPersonalRecord: item.isPersonalRecord
                    )
                }

                if let summary = item.setSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            fullTrailing
        }
        .prHighlight(item.isPersonalRecord)
    }

    // MARK: - Shared Sub-views

    @ViewBuilder
    private func activityIcon(size: CGFloat, font: Font) -> some View {
        if let equipment = item.equipment {
            equipment.svgIcon(size: size)
                .foregroundStyle(item.activityType.color)
                .accessibilityHidden(true)
        } else {
            Image(systemName: item.activityType.iconName)
                .font(.system(size: size * 0.75))
                .foregroundStyle(item.activityType.color)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private var titleRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(item.displayName)
                .font(style == .compact ? .subheadline.weight(.medium) : .headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            sourceBadge
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if item.source == .healthKit || item.isLinkedToHealthKit {
            Image(systemName: "apple.logo")
                .font(.caption2)
                .foregroundStyle(.pink)
                .accessibilityLabel(item.source == .healthKit
                    ? Text("Imported from Apple Health")
                    : Text("Manual workout linked to Apple Health"))
        }
    }

    /// Full-style metrics: duration + HR + pace + elevation
    private var metricsRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            Text(item.formattedDuration)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .lineLimit(1)
                .fixedSize()

            if let hrAvg = item.validHeartRateAvg {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                    Text(hrAvg.formattedWithSeparator)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.Color.heartRate)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel(Text("Average heart rate: \(hrAvg) bpm"))
            }

            if let pace = item.averagePace {
                Text(Self.formattedPace(pace))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.Color.activity)
                    .lineLimit(1)
                    .fixedSize()
            }

            if let elevation = item.elevationAscended, elevation > 0 {
                Text("↑\(Int(elevation).formattedWithSeparator)m")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var muscleBadges: some View {
        if !item.primaryMuscles.isEmpty {
            let badgeColor = item.activityType.color
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xxs))
                : AnyLayout(HStackLayout(spacing: DS.Spacing.xxs))
            layout {
                ForEach(item.primaryMuscles.prefix(3), id: \.self) { muscle in
                    Text(muscle.displayName)
                        .font(.system(size: muscleBadgeFontSize, weight: .medium))
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(badgeColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(badgeColor)
                }
            }
            .clipped()
        }
    }

    // MARK: - Trailing

    private var compactTrailing: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: DS.Spacing.xxs) {
            Text(item.formattedDuration)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(theme.heroTextGradient)
            if let cal = item.calories, cal > 0, cal < 5_000 {
                Text(item.source == .manual ? "~\(Int(cal).formattedWithSeparator) kcal" : "\(Int(cal).formattedWithSeparator) kcal")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    private var fullTrailing: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: DS.Spacing.xs) {
            if let cal = item.calories, cal > 0, cal < 5_000 {
                Text("\(Int(cal).formattedWithSeparator) kcal")
                    .font(.subheadline)
                    .foregroundStyle(theme.heroTextGradient)
            }
            Text(item.date, style: .date)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Helpers

    private static func formattedPace(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0, secPerKm < 86_400 else { return "—" }
        let totalSeconds = Int(secPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)'\(String(format: "%02d", seconds))\"/km"
    }
}

/// An earned reward for the specific workout represented by a compact row.
private struct WorkoutAchievementBadge: View {
    struct Model: Identifiable {
        let id: String
        let text: String
        let isRecord: Bool

        init(id: String, text: String, isRecord: Bool) {
            self.id = id
            self.text = text
            self.isRecord = isRecord
        }

        init?(event: WorkoutRewardEvent) {
            guard event.kind != .levelUp else { return nil }
            self.init(
                id: event.id,
                text: event.detail.isEmpty ? event.title : event.detail,
                isRecord: event.kind == .personalRecord
            )
        }
    }

    let model: Model

    private enum Palette {
        static let gold = DS.Color.activityCardio
        static let bronze = DS.Color.desertBronze
        static let sand = DS.Color.sandMuted
        static let card = DS.Color.cardBackground

        static let medalFace = LinearGradient(
            colors: [sand, gold, bronze],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let achievementFill = LinearGradient(
            colors: [card, gold.opacity(0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let recordFill = LinearGradient(
            colors: [gold.opacity(0.72), sand, gold.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            emblem

            Text(model.text)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if model.isRecord {
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundStyle(Palette.bronze)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(model.isRecord ? DS.Color.onBrightAction : DS.Color.textSecondary)
        .padding(.leading, 4)
        .padding(.trailing, DS.Spacing.sm)
        .padding(.vertical, 4)
        .background(
            model.isRecord ? Palette.recordFill : Palette.achievementFill,
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(Palette.gold.opacity(0.65), lineWidth: 1)
        }
        .accessibilityLabel(model.isRecord
            ? Text("Personal record: \(model.text)")
            : Text("Achievement: \(model.text)"))
    }

    private var emblem: some View {
        ZStack {
            if !model.isRecord {
                MedalRibbon()
                    .fill(Palette.bronze.gradient)
                    .frame(width: 13, height: 13)
                    .offset(y: 12)
            }
            Circle()
                .fill(Palette.medalFace)
                .frame(width: 26, height: 26)
                .overlay {
                    Circle()
                        .strokeBorder(Palette.gold.opacity(0.8), lineWidth: 1)
                }
            Image(systemName: model.isRecord ? "trophy.fill" : "medal.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(DS.Color.onBrightAction)
        }
        .frame(width: 26, height: 30)
        .accessibilityHidden(true)
    }
}

private struct MedalRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.72))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
