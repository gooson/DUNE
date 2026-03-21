#if !os(visionOS)
import SwiftUI

/// Overlay displaying exercise form check results during realtime analysis.
struct FormCheckOverlay: View {
    let formState: ExerciseFormState
    let exerciseName: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

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
                        .background(phaseColor.opacity(0.6), in: Capsule())
                }

                // Rep counter
                HStack {
                    Label(String(localized: "Reps"), systemImage: "repeat")
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
                            .fill(statusColor(result.status))
                            .frame(width: 8, height: 8)
                        Text(result.checkpointName)
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                        if result.status != .unmeasurable {
                            Text("\(Int(result.currentDegrees))°")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.8))
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }

                // Current rep score
                if formState.currentRepScore > 0 {
                    HStack {
                        Text(String(localized: "Form Score"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text("\(formState.currentRepScore)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(scoreColor(formState.currentRepScore))
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Colors

    private var phaseColor: Color {
        switch formState.currentPhase {
        case .setup, .lockout: return .blue
        case .descent: return .orange
        case .bottom: return .red
        case .ascent: return .green
        }
    }

    private func statusColor(_ status: PostureStatus) -> Color {
        switch status {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .red
        case .unmeasurable: return .gray
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Phase Display Name

extension ExercisePhase {
    var displayName: String {
        switch self {
        case .setup: return String(localized: "Setup")
        case .descent: return String(localized: "Descent")
        case .bottom: return String(localized: "Bottom")
        case .ascent: return String(localized: "Ascent")
        case .lockout: return String(localized: "Lockout")
        }
    }
}
#endif
