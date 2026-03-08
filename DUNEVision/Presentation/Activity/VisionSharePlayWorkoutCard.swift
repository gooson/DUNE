import SwiftUI

struct VisionSharePlayWorkoutCard: View {
    @State private var viewModel: VisionSharePlayWorkoutViewModel

    @MainActor
    init(viewModel: VisionSharePlayWorkoutViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? VisionSharePlayWorkoutViewModel())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            sharePlayControls
            localWorkoutEditor

            if let errorMessage = viewModel.errorMessage {
                messageCard(
                    message: errorMessage,
                    tint: .orange,
                    icon: "exclamationmark.triangle.fill"
                )
            } else if let infoMessage = viewModel.infoMessage {
                messageCard(
                    message: infoMessage,
                    tint: .secondary,
                    icon: "person.2.wave.2.fill"
                )
            }

            participantBoard
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SharePlay Workout Space")
                .font(.title2.weight(.semibold))

            Text("Start a shared workout board so everyone can keep the current exercise, sets, and reps aligned in Vision Pro.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var sharePlayControls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.startSharePlay() }
            } label: {
                Label(viewModel.sharePlayButtonTitle, systemImage: "shareplay")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartSharePlay)

            Text(viewModel.sessionBadgeTitle)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(sessionBadgeBackground, in: Capsule())
        }
    }

    private var localWorkoutEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Exercise")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(
                "Enter exercise name",
                text: Binding(
                    get: { viewModel.exerciseName },
                    set: { viewModel.exerciseName = $0 }
                )
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack(spacing: 12) {
                metricControl(
                    title: "Sets",
                    value: "\(viewModel.completedSets)",
                    decrease: viewModel.decreaseSets,
                    increase: viewModel.increaseSets
                )
                metricControl(
                    title: "Target Reps",
                    value: "\(viewModel.targetReps)",
                    decrease: viewModel.decreaseTargetReps,
                    increase: viewModel.increaseTargetReps
                )
                phaseControl
            }
        }
    }

    private var phaseControl: some View {
        Button {
            viewModel.advancePhase()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Phase")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label(viewModel.phase.displayName, systemImage: viewModel.phase.systemImage)
                    .font(.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var participantBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Participant Board")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.activeParticipantCount)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if viewModel.participants.count == 1 {
                Text("Invite a friend to see shared workout updates here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(viewModel.participants) { participant in
                    participantCard(participant)
                }
            }
        }
    }

    private func metricControl(
        title: LocalizedStringKey,
        value: String,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)

                Text(verbatim: value)
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 36)

                Button(action: increase) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func participantCard(_ participant: VisionSharePlayParticipantBoardItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: participant.title)
                    .font(.headline)
                Spacer()
                Label(participant.phase.displayName, systemImage: participant.phase.systemImage)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Text(verbatim: participant.exerciseName)
                .font(.title3.weight(.semibold))

            if participant.isPlaceholder {
                Text("Waiting for the first live update.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 14) {
                    statColumn(title: "Sets", value: "\(participant.completedSets)")
                    statColumn(
                        title: "Target Reps",
                        value: participant.targetReps > 0 ? "\(participant.targetReps)" : "--"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statColumn(
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
    }

    private func messageCard(
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

    private var sessionBadgeBackground: AnyShapeStyle {
        switch viewModel.sessionState {
        case .sharing:
            AnyShapeStyle(Color.green.opacity(0.18))
        case .preparing:
            AnyShapeStyle(Color.yellow.opacity(0.18))
        case .unsupported, .failed:
            AnyShapeStyle(Color.orange.opacity(0.18))
        case .idle:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}
