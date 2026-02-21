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
                .foregroundStyle(.secondary)
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
        case .hrv:               "\(String(format: "%.0f", value)) ms"
        case .rhr:               "\(String(format: "%.0f", value)) bpm"
        case .heartRate:         "\(String(format: "%.0f", value)) bpm"
        case .sleep:             value.hoursMinutesFormatted
        case .exercise:          "\(String(format: "%.0f", value)) min"
        case .steps:             "\(String(format: "%.0f", value))"
        case .weight:            "\(String(format: "%.1f", value)) kg"
        case .bmi:               "\(String(format: "%.1f", value))"
        case .bodyFat:           "\(String(format: "%.1f", value))%"
        case .leanBodyMass:      "\(String(format: "%.1f", value)) kg"
        case .spo2:              "\(String(format: "%.0f", value * 100))%"
        case .respiratoryRate:   "\(String(format: "%.0f", value)) breaths/min"
        case .vo2Max:            "\(String(format: "%.1f", value)) ml/kg/min"
        case .heartRateRecovery: "\(String(format: "%.0f", value)) bpm"
        case .wristTemperature:  "\(String(format: "%+.1f", value)) °C"
        }
    }
}
