import SwiftUI

/// Real-time guidance checklist showing capture readiness conditions.
struct GuidanceChecklistView: View {
    let guidanceState: GuidanceState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            checklistItem(
                satisfied: guidanceState.isFullBodyVisible,
                icon: "figure.stand",
                label: String(localized: "Full body visible")
            )
            checklistItem(
                satisfied: guidanceState.distanceStatus == .optimal || guidanceState.distanceStatus == .slightlyFar,
                icon: "arrow.left.and.right",
                label: String(localized: "Distance OK")
            )
            checklistItem(
                satisfied: guidanceState.isStable,
                icon: "hand.raised.slash",
                label: String(localized: "Holding still")
            )
            checklistItem(
                satisfied: guidanceState.lightingStatus != .tooLow,
                icon: "sun.max",
                label: String(localized: "Lighting OK")
            )
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func checklistItem(satisfied: Bool, icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(satisfied ? .green : .white.opacity(0.5))

            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(satisfied ? .white : .white.opacity(0.6))
        }
        .animation(.easeInOut(duration: 0.2), value: satisfied)
    }
}
