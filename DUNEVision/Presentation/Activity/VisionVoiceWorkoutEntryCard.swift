import SwiftData
import SwiftUI

struct VisionVoiceWorkoutEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: VisionVoiceWorkoutEntryViewModel

    init(viewModel: VisionVoiceWorkoutEntryViewModel = VisionVoiceWorkoutEntryViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            transcriptField
            controls

            if let errorMessage = viewModel.errorMessage {
                feedbackCard(message: errorMessage, tint: .orange, icon: "exclamationmark.triangle.fill")
            } else if let infoMessage = viewModel.infoMessage {
                feedbackCard(message: infoMessage, tint: .secondary, icon: "waveform")
            }

            if let draft = viewModel.draft {
                draftCard(draft)
            } else {
                placeholderCard
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onDisappear {
            viewModel.stopListening()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice Quick Entry")
                .font(.title2.weight(.semibold))

            Text("Speak a workout like \"Bench Press 80kg 8 reps\" to review it and save a quick entry without leaving Vision Pro.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var transcriptField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transcript")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(
                "Speak or type your workout command",
                text: Binding(
                    get: { viewModel.transcript },
                    set: { viewModel.transcript = $0 }
                ),
                axis: .vertical
            )
            .lineLimit(3...5)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleListening() }
            } label: {
                Label(
                    viewModel.listeningButtonTitle,
                    systemImage: viewModel.isListening ? "stop.fill" : "mic.fill"
                )
            }
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.reviewDraft()
            } label: {
                Label("Review Draft", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canParse)
        }
    }

    private func feedbackCard(
        message: String,
        tint: Color,
        icon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func draftCard(_ draft: VisionVoiceWorkoutDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Draft Preview")
                    .font(.headline)
                Text(verbatim: draft.primaryDisplayName())
                    .font(.title3.weight(.semibold))
                if let secondaryName = draft.secondaryDisplayName() {
                    Text(verbatim: secondaryName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                if let weight = draft.weight, let unit = draft.weightUnit {
                    metricChip(
                        title: "Weight",
                        value: "\(weight.formatted(.number.precision(.fractionLength(0...1)))) \(unit.displayName)"
                    )
                }
                if let reps = draft.reps {
                    metricChip(title: "Reps", value: "\(reps)")
                }
                if let durationSeconds = draft.durationSeconds {
                    metricChip(title: "Duration", value: formattedDuration(durationSeconds))
                }
                if let distance = draft.distance, let unit = draft.distanceUnit {
                    metricChip(
                        title: "Distance",
                        value: "\(distance.formatted(.number.precision(.fractionLength(0...1)))) \(unit.displayName)"
                    )
                }
            }

            Text("Save this draft to workout history when it looks right.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                saveDraft()
            } label: {
                Label(
                    viewModel.saveButtonTitle,
                    systemImage: viewModel.isDraftSaved ? "checkmark.circle.fill" : "square.and.arrow.down.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Draft Preview")
                .font(.headline)
            Text("No draft yet. Capture a transcript, then review it to see the structured workout entry.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func metricChip(
        title: LocalizedStringKey,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formattedDuration(_ durationSeconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .short
        return formatter.string(from: durationSeconds) ?? "\(Int(durationSeconds))s"
    }

    private func saveDraft() {
        guard let record = viewModel.createValidatedRecord() else { return }
        modelContext.insert(record)
        viewModel.didFinishSaving()
    }
}
