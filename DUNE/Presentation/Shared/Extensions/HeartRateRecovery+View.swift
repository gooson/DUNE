import SwiftUI

extension HeartRateRecovery.Rating {
    var color: Color {
        switch self {
        case .low: .red
        case .normal: .yellow
        case .good: .green
        }
    }
}

/// Shared recovery row displayed in workout detail views.
struct HeartRateRecoveryRow: View {
    let recovery: HeartRateRecovery

    @State private var showingInfoSheet = false

    var body: some View {
        if recovery.hrr1 > 0 {
            let ratingColor = recovery.rating.color
            HStack {
                Label("Recovery", systemImage: "arrow.down.heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)

                Button {
                    showingInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Text("\(Int(recovery.hrr1))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(recovery.rating.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ratingColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            ratingColor.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .padding(.top, DS.Spacing.xs)
            .sheet(isPresented: $showingInfoSheet) {
                HeartRateRecoveryInfoSheet()
            }
        }
    }
}

// MARK: - Info Sheet

/// Explains what HRR₁ means and how the rating is determined.
struct HeartRateRecoveryInfoSheet: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                definitionSection
                measurementSection
                Divider()
                ratingGuideSection
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.heartRate)

            Text("What is Heart Rate Recovery?")
                .font(.headline)

            Spacer()
        }
    }

    // MARK: - Definition

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "heart.text.clipboard", title: "Definition")

            Text("Heart Rate Recovery (HRR₁) measures how quickly your heart rate drops in the first minute after exercise. A faster drop indicates better cardiovascular fitness and autonomic nervous system recovery.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Measurement

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "applewatch", title: "How It's Measured")

            Text("Your peak heart rate at the end of the workout is compared to the heart rate measured about 60 seconds after the workout ends. The difference is your HRR₁ value.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Rating Guide

    private var ratingGuideSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "gauge.with.needle", title: "Rating Guide")

            VStack(spacing: DS.Spacing.xs) {
                ratingRow(label: "Good", range: "> 20 bpm", color: .green)
                ratingRow(label: "Normal", range: "12–20 bpm", color: .yellow)
                ratingRow(label: "Low", range: "< 12 bpm", color: .red)
            }
        }
    }

    // MARK: - Helpers

    private func ratingRow(label: LocalizedStringKey, range: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(range)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
