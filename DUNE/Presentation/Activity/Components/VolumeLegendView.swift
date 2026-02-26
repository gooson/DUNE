import SwiftUI

/// Compact gradient legend for the 5-level volume system.
/// Mirrors FatigueLegendView structure for visual consistency.
struct VolumeLegendView: View {
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            gradientBar
            labelRow
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private var gradientBar: some View {
        HStack(spacing: 1) {
            ForEach(VolumeIntensity.allCases, id: \.rawValue) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level.color)
                    .frame(height: 6)
                    .overlay {
                        if level == .none {
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }

    private var labelRow: some View {
        HStack(spacing: 0) {
            ForEach(VolumeIntensity.allCases, id: \.rawValue) { level in
                Text(level == .none ? "0 sets" : level.label)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
    }
}
