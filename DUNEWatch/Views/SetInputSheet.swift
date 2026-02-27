import SwiftUI
import WatchKit

/// Dedicated sheet for weight/reps input with Digital Crown support.
/// Crown controls weight (scroll = touch), layout adapts to any watch size.
/// Shows previous set history for reference when available.
struct SetInputSheet: View {
    @Binding var weight: Double
    @Binding var reps: Int
    /// Previously completed sets for the current exercise (newest last)
    var previousSets: [CompletedSetData] = []
    @Environment(\.dismiss) private var dismiss

    @State private var lastHapticDate: Date = .distantPast

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Previous set history (if any)
                if !previousSets.isEmpty {
                    previousSetHistory
                    Divider()
                }

                // Weight — large display + crown + ±2.5 buttons
                weightSection

                Divider()

                // Reps — inline ± row
                repsSection
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        // Done at bottom via toolbar — always visible regardless of scroll
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .focusable()
        .digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)
        .onChange(of: weight) { _, newValue in
            let clamped = min(max(newValue, 0), 500)
            if clamped != newValue { weight = clamped }
        }
    }

    // MARK: - Weight

    private var weightSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("\(weight, specifier: "%.1f")")
                .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(DS.Color.positive)
                .contentTransition(.numericText())

            Text("kg")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            // ± buttons for quick jumps (crown for fine tuning)
            HStack(spacing: DS.Spacing.md) {
                weightButton("-2.5", delta: -2.5)
                weightButton("+2.5", delta: 2.5)
            }
        }
    }

    private func weightButton(_ label: String, delta: Double) -> some View {
        Button {
            let newValue = weight + delta
            if (0...500).contains(newValue) {
                weight = newValue
                playDebouncedHaptic()
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    // MARK: - Reps

    private var repsSection: some View {
        HStack {
            Button {
                if reps > 0 {
                    reps -= 1
                    playDebouncedHaptic()
                }
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()

            VStack(spacing: 0) {
                Text("\(reps)")
                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(DS.Color.positive)
                    .contentTransition(.numericText())
                Text("reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if reps < 100 {
                    reps += 1
                    playDebouncedHaptic()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    // MARK: - Previous Sets

    private var previousSetHistory: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Previous Sets")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            ForEach(previousSets, id: \.setNumber) { set in
                HStack(spacing: DS.Spacing.sm) {
                    Text("Set \(set.setNumber)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 36, alignment: .leading)

                    if let w = set.weight, w > 0 {
                        Text("\(w, specifier: "%.1f")kg")
                            .font(.caption2.monospacedDigit())
                    }

                    if let r = set.reps, r > 0 {
                        Text("\u{00d7}\(r)")
                            .font(.caption2.monospacedDigit())
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Haptic

    private func playDebouncedHaptic() {
        let now = Date()
        guard now.timeIntervalSince(lastHapticDate) >= 0.1 else { return }
        lastHapticDate = now
        WKInterfaceDevice.current().play(.click)
    }
}
