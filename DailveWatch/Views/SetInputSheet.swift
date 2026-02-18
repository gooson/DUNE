import SwiftUI
import WatchKit

/// Dedicated sheet for weight/reps input with Digital Crown support.
/// Crown controls weight (scroll = touch), layout adapts to any watch size.
struct SetInputSheet: View {
    @Binding var weight: Double
    @Binding var reps: Int
    @Environment(\.dismiss) private var dismiss

    @State private var lastHapticDate: Date = .distantPast

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Weight — large display + crown + ±2.5 buttons
                weightSection

                Divider()

                // Reps — inline ± row
                repsSection
            }
            .padding(.horizontal, 8)
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
        VStack(spacing: 6) {
            Text("\(weight, specifier: "%.1f")")
                .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(.green)
                .contentTransition(.numericText())

            Text("kg")
                .font(.caption)
                .foregroundStyle(.secondary)

            // ± buttons for quick jumps (crown for fine tuning)
            HStack(spacing: 8) {
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
        .tint(.gray)
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
            .tint(.gray)

            Spacer()

            VStack(spacing: 0) {
                Text("\(reps)")
                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(.green)
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
            .tint(.gray)
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
