import SwiftUI

/// Shows all historical data for a metric category, grouped by date.
struct AllDataView: View {
    let category: HealthMetric.Category

    @State private var viewModel = AllDataViewModel()
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 30

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if viewModel.limitedHistoryStartDate != nil {
                LimitedHealthHistoryNotice()
                    .listRowSeparator(.hidden)
            }

            if viewModel.dataPoints.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: category.iconName,
                    title: "No Data",
                    message: viewModel.limitedHistoryStartDate != nil
                        ? "No data in the available range."
                        : "No data available yet."
                )
                .accessibilityIdentifier("all-data-empty-state")
                .listRowSeparator(.hidden)
            }

            ForEach(viewModel.groupedByDate, id: \.date) { section in
                Section {
                    ForEach(section.points) { point in
                        dataRow(point)
                    }
                } header: {
                    Text(section.date, format: .dateTime.year().month(.wide).day())
                }
            }

            if viewModel.hasMoreData {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task(id: viewModel.dataPoints.count) {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .accessibilityIdentifier("all-data-screen-\(category.rawValue)")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background { DetailWaveBackground() }
        .environment(\.waveColor, category.themeColor)
        .englishNavigationTitle(category.englishDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.configure(category: category)
            await viewModel.loadInitialData()
        }
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.lg))
        return layout {
            Image(systemName: category.iconName)
                .font(.system(size: min(iconSize, 42), weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: min(iconSize + 20, 64), height: min(iconSize + 20, 64))
                .background(palette.ink.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .accessibilityIdentifier("all-data-header-icon")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("History")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.muted)
                Text(category.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("all-data-header-title")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    LinearGradient(colors: [palette.heroAccent.opacity(0.28), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                    DesertDuneOverlayView(color: palette.heroHighlight, opacity: 0.12,
                                          amplitude: 0.12, frequency: 0.7, verticalOffset: 0.60,
                                          bottomFade: 0, driftDuration: 0,
                                          crestColor: palette.heroAccent, crestOpacity: 0.20)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("all-data-header")
    }

    // MARK: - Row

    private func dataRow(_ point: ChartDataPoint) -> some View {
        let displayDate = point.displayDate ?? point.date

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.md))
        return layout {
            Text(displayDate, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("all-data-row-time")

            Text(formattedValue(point.value))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity,
                       alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                .accessibilityIdentifier("all-data-row-value")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayDate, format: .dateTime.hour().minute()), \(formattedValue(point.value))")
    }

    // MARK: - Helpers

    private func formattedValue(_ value: Double) -> String {
        switch category {
        case .hrv:               "\(value.formattedWithSeparator()) ms"
        case .rhr:               "\(value.formattedWithSeparator()) bpm"
        case .heartRate:         "\(value.formattedWithSeparator()) bpm"
        case .sleep:             value.hoursMinutesFormatted
        case .exercise:          "\(value.formattedWithSeparator()) min"
        case .steps:             value.formattedWithSeparator()
        case .weight:            "\(value.formattedWithSeparator(fractionDigits: 1)) kg"
        case .bmi:               value.formattedWithSeparator(fractionDigits: 1)
        case .bodyFat:           "\(value.formattedWithSeparator(fractionDigits: 1))%"
        case .leanBodyMass:      "\(value.formattedWithSeparator(fractionDigits: 1)) kg"
        case .spo2:              "\((value * 100).formattedWithSeparator())%"
        case .respiratoryRate:   "\(value.formattedWithSeparator()) breaths/min"
        case .vo2Max:            "\(value.formattedWithSeparator(fractionDigits: 1)) ml/kg/min"
        case .heartRateRecovery: "\(value.formattedWithSeparator()) bpm"
        case .wristTemperature:  "\(value.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true)) °C"
        case .breathingDisturbances: "\(value.formattedWithSeparator(fractionDigits: 1))/hr"
        }
    }
}
