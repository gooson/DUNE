import SwiftUI

/// RPE slider picker for individual sets (6.0–10.0, 0.5 step) with color spectrum.
struct SetRPEPickerView: View {
    @Binding var rpe: Double?

    @State private var sliderValue: Double = 8.0
    @State private var isActive: Bool = false
    @State private var showHelp = false

    private static let categoryLabels: [(label: String, position: Double)] = [
        (String(localized: "Light"), 6.0),
        (String(localized: "Moderate"), 7.0),
        (String(localized: "Hard"), 8.0),
        (String(localized: "Very Hard"), 9.0),
        (String(localized: "Max"), 10.0),
    ]

    private var currentColor: Color {
        switch sliderValue {
        case ..<7.0: DS.Color.positive
        case 7.0..<8.0: DS.Color.caution
        case 8.0..<9.0: .orange
        default: DS.Color.negative
        }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if isActive {
                rpeHeader
                rpeDisplay
                rpeSlider
                rpeCategoryLabels
            } else {
                inactiveState
            }
        }
        .animation(DS.Animation.snappy, value: isActive)
        .task {
            if let rpe {
                sliderValue = rpe
                isActive = true
            }
        }
        .sheet(isPresented: $showHelp) {
            RPEHelpSheet()
        }
    }

    // MARK: - Inactive State

    private var inactiveState: some View {
        Button {
            withAnimation(DS.Animation.snappy) {
                isActive = true
                sliderValue = 8.0
                rpe = 8.0
            }
        } label: {
            HStack {
                Text("RPE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)

                Spacer()

                Text("Tap to rate")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var rpeHeader: some View {
        HStack {
            Text("RPE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            Spacer()

            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(DS.Animation.snappy) {
                    isActive = false
                    rpe = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - RPE Display

    private var rpeDisplay: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(RPELevel.format(sliderValue))
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(currentColor)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 2) {
                let level = RPELevel(value: sliderValue)
                Text(level.displayLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(currentColor)
                    .contentTransition(.interpolate)

                Text("\(level.rir) reps left")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .animation(DS.Animation.snappy, value: sliderValue)
    }

    // MARK: - Slider

    private var rpeSlider: some View {
        Slider(
            value: $sliderValue,
            in: RPELevel.range,
            step: RPELevel.step
        ) {
            Text("RPE")
        } minimumValueLabel: {
            Text("6")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(DS.Color.textSecondary)
        } maximumValueLabel: {
            Text("10")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(DS.Color.textSecondary)
        }
        .tint(currentColor)
        .sensoryFeedback(.selection, trigger: sliderValue)
        .onChange(of: sliderValue) { _, newValue in
            rpe = newValue
        }
    }

    // MARK: - Category Labels

    private var rpeCategoryLabels: some View {
        HStack {
            ForEach(Self.categoryLabels, id: \.position) { item in
                let isCurrentCategory = isCurrent(position: item.position)
                Text(item.label)
                    .font(.caption2)
                    .foregroundStyle(isCurrentCategory ? currentColor : DS.Color.textSecondary)
                    .fontWeight(isCurrentCategory ? .semibold : .regular)
                if item.position < 10.0 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    private func isCurrent(position: Double) -> Bool {
        switch position {
        case 6.0: sliderValue < 7.0
        case 7.0: sliderValue >= 7.0 && sliderValue < 8.0
        case 8.0: sliderValue >= 8.0 && sliderValue < 9.0
        case 9.0: sliderValue >= 9.0 && sliderValue < 10.0
        case 10.0: sliderValue >= 10.0
        default: false
        }
    }
}

#Preview("Set RPE Picker") {
    struct PreviewWrapper: View {
        @State private var rpe: Double? = 8.0

        var body: some View {
            VStack(spacing: DS.Spacing.xl) {
                SetRPEPickerView(rpe: $rpe)
                    .padding(.horizontal)

                if let rpe {
                    let level = RPELevel(value: rpe)
                    Text("\(level.displayLabel) — \(level.rir) RIR")
                        .font(.caption)
                } else {
                    Text("No RPE selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Set RPE Picker - No Selection") {
    struct PreviewWrapper: View {
        @State private var rpe: Double?

        var body: some View {
            SetRPEPickerView(rpe: $rpe)
                .padding()
        }
    }

    return PreviewWrapper()
}
