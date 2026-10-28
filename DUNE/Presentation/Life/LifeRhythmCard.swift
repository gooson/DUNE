import SwiftUI

/// Both summaries use the same manual, current-habit completion snapshot.
struct LifeRhythmCard: View {
    let points: [WeeklyHeroTrendPoint]
    let onDetail: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var week: [WeeklyHeroTrendPoint] { Array(points.suffix(7)) }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Button(action: onDetail) {
                    CardNavigationHeader {
                        Label("Practice Rhythm", systemImage: "chart.bar.fill")
                            .font(.headline)
                    }
                }
                .buttonStyle(CardNavigationButtonStyle())
                .accessibilityIdentifier("habit-heatmap")

                Text("\(week.compactMap(\.value).reduce(0, +)) completions")
                    .font(.largeTitle.bold()).monospacedDigit()
                    .foregroundStyle(theme.accentColor)
                Text("Based on currently registered habits")
                    .font(.caption).foregroundStyle(.secondary)

                WeeklyHeroTrendView(
                    points: week, title: "Daily completions",
                    upperBound: max(1, week.compactMap(\.value).max() ?? 0),
                    tint: theme.accentColor, accessibilityIdentifier: "life-hero-trend"
                )

                Text("28-day pattern").font(.subheadline.weight(.semibold))
                // An eager grid inside the isolated query subtree keeps identity stable.
                Grid(horizontalSpacing: DS.Spacing.xs, verticalSpacing: DS.Spacing.xs) {
                    ForEach(0..<4) { row in
                        GridRow {
                            ForEach(0..<7) { column in
                                let index = row * 7 + column
                                if index < points.count {
                                    let point = points[index]
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.accentColor.opacity(opacity(point.value)))
                                        .overlay {
                                            if point.value == nil {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2]))
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 24 : 18)
                                        .accessibilityLabel(Text(point.date, format: .dateTime.month().day()))
                                        .accessibilityValue(point.value.map { $0.formattedWithSeparator } ?? String(localized: "Before start"))
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("life-rhythm-pattern")
                Text("Before start · 0 · 1 · 2 · 3+")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func opacity(_ value: Int?) -> Double {
        guard let value else { return 0 }
        switch value {
        case ...0: return 0.08
        case 1: return 0.3
        case 2: return 0.6
        default: return 1
        }
    }
}

struct LifeWeeklyReviewCard: View {
    let points: [WeeklyHeroTrendPoint]
    let onDetail: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var currentWeek: [WeeklyHeroTrendPoint] { points }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Button(action: onDetail) {
                    CardNavigationHeader {
                        Label("Weekly Reflection", systemImage: "sparkles")
                            .font(.headline)
                    }
                }
                .buttonStyle(CardNavigationButtonStyle())
                .accessibilityIdentifier("life-weekly-report-button")
                if let first = currentWeek.first, let last = currentWeek.last {
                    Text(verbatim: "\(first.date.formatted(.dateTime.month().day())) – \(last.date.formatted(.dateTime.month().day()))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.lg))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.xl))
                layout {
                    metric(currentWeek.filter { ($0.value ?? 0) > 0 }.count, title: "Days recorded")
                    metric(currentWeek.compactMap(\.value).reduce(0, +), title: "Completed practices")
                }
                Text("Based on currently registered habits")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ value: Int, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(value.formattedWithSeparator)
                .font(.largeTitle.bold()).monospacedDigit().foregroundStyle(theme.accentColor)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LifeRhythmCard(points: []) { }
        .padding()
}
