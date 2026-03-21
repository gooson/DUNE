#if !os(visionOS)
import SwiftUI

/// Overlay displaying exercise form check results during realtime analysis.
struct FormCheckOverlay: View {
    let formState: ExerciseFormState
    let exerciseName: String

    var body: some View {
        VStack(spacing: 8) {
            // Exercise name + phase
            HStack {
                Text(exerciseName)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(formState.currentPhase.displayName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(StatusColors.phase(formState.currentPhase).opacity(0.6), in: Capsule())
            }

            // Rep counter
            HStack {
                Label("Reps", systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(formState.repCount)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }

            // Checkpoint results
            ForEach(formState.checkpointResults) { result in
                HStack {
                    Circle()
                        .fill(StatusColors.status(result.status))
                        .frame(width: 8, height: 8)
                    Text(result.checkpointName)
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    if result.status != .unmeasurable {
                        Text("\(Int(result.currentDegrees))\u{00B0}")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("--")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .accessibilityElement(children: .combine)
            }

            // Current rep score
            if formState.currentRepScore > 0 {
                HStack {
                    Text("Form Score")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(formState.currentRepScore)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(StatusColors.score(formState.currentRepScore))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Static Color Constants

private enum StatusColors {
    static let normalColor: Color = .green
    static let cautionColor: Color = .yellow
    static let warningColor: Color = .red
    static let unmeasurableColor: Color = .gray

    static func status(_ status: PostureStatus) -> Color {
        switch status {
        case .normal: normalColor
        case .caution: cautionColor
        case .warning: warningColor
        case .unmeasurable: unmeasurableColor
        }
    }

    static func phase(_ phase: ExercisePhase) -> Color {
        switch phase {
        case .setup, .lockout: .blue
        case .descent: .orange
        case .bottom: .red
        case .ascent: .green
        }
    }

    static func score(_ score: Int) -> Color {
        if score >= 80 { return normalColor }
        if score >= 50 { return cautionColor }
        return warningColor
    }
}

// MARK: - Phase Display Name

extension ExercisePhase {
    var displayName: String {
        switch self {
        case .setup: String(localized: "Setup")
        case .descent: String(localized: "Descent")
        case .bottom: String(localized: "Bottom")
        case .ascent: String(localized: "Ascent")
        case .lockout: String(localized: "Lockout")
        }
    }
}
#endif
