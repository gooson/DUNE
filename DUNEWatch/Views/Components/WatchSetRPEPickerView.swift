import SwiftUI
import WatchKit

/// RPE slider picker for watchOS with Digital Crown support (6.0–10.0, 0.5 step).
struct WatchSetRPEPickerView: View {
    @Binding var rpe: Double?

    @State private var sliderValue: Double
    @State private var isActive: Bool
    @State private var showHelp = false

    init(rpe: Binding<Double?>) {
        _rpe = rpe
        _sliderValue = State(initialValue: rpe.wrappedValue ?? 8.0)
        _isActive = State(initialValue: rpe.wrappedValue != nil)
    }

    private var currentColor: Color {
        switch sliderValue {
        case ..<7.0: DS.Color.positive
        case 7.0..<8.0: DS.Color.caution
        case 8.0..<9.0: .orange
        default: DS.Color.negative
        }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            if isActive {
                rpeHeader
                rpeDisplay
                rpeSlider
            } else {
                inactiveState
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .sheet(isPresented: $showHelp) {
            WatchRPEHelpSheet()
        }
    }

    // MARK: - Inactive State

    private var inactiveState: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isActive = true
                    sliderValue = 8.0
                    rpe = 8.0
                }
                WKInterfaceDevice.current().play(.click)
            } label: {
                HStack {
                    Text("RPE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.Color.textSecondary)

                    Spacer()

                    Text("Tap to rate")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
                    .frame(minWidth: 38, minHeight: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("RPE Help"))
        }
    }

    // MARK: - Header

    private var rpeHeader: some View {
        HStack {
            Text("RPE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            Spacer()

            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
                    .frame(minWidth: 38, minHeight: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("RPE Help"))

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isActive = false
                    rpe = nil
                }
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
                    .frame(minWidth: 38, minHeight: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Clear RPE"))
        }
    }

    // MARK: - RPE Display

    private var rpeDisplay: some View {
        VStack(spacing: 2) {
            Text(RPELevel.format(sliderValue))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(currentColor)
                .contentTransition(.numericText())

            let level = RPELevel(value: sliderValue)
            Text(level.displayLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(currentColor)

            Text("\(level.rir) reps left")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .animation(.easeInOut(duration: 0.2), value: sliderValue)
    }

    // MARK: - Slider

    private var rpeSlider: some View {
        Slider(
            value: $sliderValue,
            in: RPELevel.range,
            step: RPELevel.step
        ) {
            Text("RPE")
        }
        .tint(currentColor)
        .sensoryFeedback(.selection, trigger: sliderValue)
        .onChange(of: sliderValue) { _, newValue in
            rpe = newValue
        }
    }
}

#Preview("Watch RPE Picker") {
    struct PreviewWrapper: View {
        @State private var rpe: Double? = 8.0

        var body: some View {
            ScrollView {
                WatchSetRPEPickerView(rpe: $rpe)
                    .padding(.horizontal)

                if let rpe {
                    Text("\(RPELevel(value: rpe).displayLabel)")
                        .font(.caption2)
                } else {
                    Text("No RPE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    return PreviewWrapper()
}
