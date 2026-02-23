import SwiftUI
import SwiftData
import Charts

/// Full detail view for Personal Records with timeline chart and complete PR list.
struct PersonalRecordsDetailView: View {
    @State private var viewModel = PersonalRecordsDetailViewModel()
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.personalRecords.isEmpty {
                    emptyState
                } else {
                    timelineChart
                    prGrid
                }
            }
            .padding()
        }
        .navigationTitle("Personal Records")
        .task(id: exerciseRecords.count) {
            viewModel.loadRecords(from: exerciseRecords)
        }
    }

    // MARK: - Timeline Chart

    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("PR Timeline")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(viewModel.personalRecords) { record in
                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Weight", record.maxWeight)
                )
                .foregroundStyle(DS.Color.activity)
                .symbolSize(record.isRecent ? 80 : 40)
                .annotation(position: .top, spacing: 4) {
                    if record.isRecent {
                        Text(record.exerciseName)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.formattedWithSeparator())
                        }
                    }
                }
            }
            .frame(height: 200)
            .clipped()
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Full PR Grid

    private var prGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("All Records")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(viewModel.personalRecords) { record in
                    prCard(record)
                }
            }
        }
    }

    private func prCard(_ record: StrengthPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(record.exerciseName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(record.maxWeight.formattedWithSeparator())
                    .font(DS.Typography.cardScore)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

            Text(record.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No personal records yet.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Log sets with weight to start tracking your PRs.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
