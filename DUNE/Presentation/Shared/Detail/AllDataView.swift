import SwiftUI

/// Shows all historical data for a metric category, grouped by date.
struct AllDataView: View {
    let category: HealthMetric.Category

    @State private var viewModel = AllDataViewModel()

    var body: some View {
        List {
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
                    .task {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .environment(\.waveColor, category.themeColor)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.dataPoints.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: category.iconName,
                    title: "No Data",
                    message: "No \(category.displayName.lowercased()) data available yet."
                )
            }
        }
        .task {
            viewModel.configure(category: category)
            await viewModel.loadInitialData()
        }
    }

    // MARK: - Row

    private func dataRow(_ point: ChartDataPoint) -> some View {
        HStack {
            Text(point.date, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            Text(formattedValue(point.value))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(point.date, format: .dateTime.hour().minute()), \(formattedValue(point.value))")
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
        }
    }
}
