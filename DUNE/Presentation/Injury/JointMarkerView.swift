import SwiftUI

/// Bullseye ring marker for joint injury overlay on body map.
/// Distinct from muscle filled regions — uses concentric circles with severity color.
struct JointMarkerView: View {
    let severity: InjurySeverity
    let isActive: Bool

    private var color: Color { severity.color }

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(color.opacity(isActive ? 0.5 : 0.25), lineWidth: 2)

            // Inner filled dot
            Circle()
                .fill(color.opacity(isActive ? 0.8 : 0.4))
                .padding(4)

            // Pulse animation for active injuries
            if isActive {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1.5)
                    .scaleEffect(1.3)
            }
        }
    }
}
