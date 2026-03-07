import SwiftUI

/// visionOS Wellness tab showing sleep and body composition data.
/// Read-only view sourced from SharedHealthSnapshot.
struct VisionWellnessView: View {
    let sharedHealthDataService: SharedHealthDataService?

    @State private var snapshot: SharedHealthSnapshot?
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sleepSection
                bodySection
            }
            .padding(24)
        }
        .navigationTitle("Wellness")
        .task {
            await loadData()
        }
    }

    // MARK: - Sleep Section

    @ViewBuilder
    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Sleep", systemImage: "moon.fill")
                .font(.title2.weight(.semibold))

            if let snapshot, !snapshot.sleepDailyDurations.isEmpty {
                let recent = snapshot.sleepDailyDurations
                    .sorted { $0.date > $1.date }
                    .prefix(14)

                if let last = recent.first {
                    sleepCard(
                        title: "Last Night",
                        hours: last.totalMinutes / 60.0,
                        breakdown: last.stageBreakdown
                    )
                }

                if recent.count >= 2 {
                    let avgMinutes = recent.map(\.totalMinutes).reduce(0, +) / Double(recent.count)
                    averageSleepCard(
                        days: recent.count,
                        averageHours: avgMinutes / 60.0
                    )
                }
            } else {
                emptySleepCard
            }
        }
    }

    private func sleepCard(
        title: LocalizedStringKey,
        hours: Double,
        breakdown: [SleepStage.Stage: Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f", hours))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("hours")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        stageRow(stage: "Deep", minutes: breakdown[.deep] ?? 0)
                        stageRow(stage: "REM", minutes: breakdown[.rem] ?? 0)
                        stageRow(stage: "Core", minutes: breakdown[.core] ?? 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func stageRow(stage: LocalizedStringKey, minutes: Double) -> some View {
        HStack(spacing: 8) {
            Text(stage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(String(format: "%.0f min", minutes))
                .font(.callout.monospacedDigit())
        }
    }

    private func averageSleepCard(days: Int, averageHours: Double) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(days)-Day Average")
                    .font(.headline)
                Text("\(averageHours, specifier: "%.1f") hours per night")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptySleepCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No Sleep Data")
                .font(.headline)

            Text("Wear your Apple Watch to bed to track sleep.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Body Section

    @ViewBuilder
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Body", systemImage: "figure.stand")
                .font(.title2.weight(.semibold))

            VStack(spacing: 12) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                Text("Body Composition")
                    .font(.headline)

                Text("Body composition data is available on your iPhone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Data

    private func loadData() async {
        guard let service = sharedHealthDataService else {
            isLoaded = true
            return
        }
        snapshot = await service.fetchSnapshot()
        isLoaded = true
    }
}
