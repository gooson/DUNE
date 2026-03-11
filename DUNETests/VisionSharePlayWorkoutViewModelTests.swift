import Foundation
import Testing
@testable import DUNE

@MainActor
private final class MockVisionSharePlayWorkoutController: VisionSharePlayWorkoutControlling {
    var startResult: VisionSharePlayWorkoutStartResult = .activationRequested
    private(set) var sentStates: [VisionSharePlayWorkoutState] = []

    private let stream: AsyncStream<VisionSharePlayWorkoutSessionEvent>
    private let continuation: AsyncStream<VisionSharePlayWorkoutSessionEvent>.Continuation

    init() {
        var streamContinuation: AsyncStream<VisionSharePlayWorkoutSessionEvent>.Continuation?
        self.stream = AsyncStream { continuation in
            streamContinuation = continuation
        }
        self.continuation = streamContinuation!
    }

    func startSharing() async -> VisionSharePlayWorkoutStartResult {
        startResult
    }

    func send(_ state: VisionSharePlayWorkoutState) async throws {
        sentStates.append(state)
    }

    func events() -> AsyncStream<VisionSharePlayWorkoutSessionEvent> {
        stream
    }

    func yield(_ event: VisionSharePlayWorkoutSessionEvent) {
        continuation.yield(event)
    }
}

@Suite("VisionSharePlayWorkoutViewModel")
@MainActor
struct VisionSharePlayWorkoutViewModelTests {
    @Test("Activation disabled keeps the workout board local")
    func activationDisabledKeepsBoardLocal() async {
        let controller = MockVisionSharePlayWorkoutController()
        controller.startResult = .activationDisabled
        let viewModel = VisionSharePlayWorkoutViewModel(controller: controller)

        await viewModel.startSharePlay()

        #expect(viewModel.sessionState == .idle)
        #expect(viewModel.infoMessage == String(localized: "SharePlay becomes available during a FaceTime call or nearby session."))
        #expect(controller.sentStates.isEmpty)
    }

    @Test("Session join replays the current local workout state")
    func sessionJoinReplaysLocalState() async {
        let controller = MockVisionSharePlayWorkoutController()
        let viewModel = VisionSharePlayWorkoutViewModel(controller: controller)
        viewModel.exerciseName = "Bench Press"
        viewModel.increaseSets()

        controller.yield(
            .sessionJoined(
                localParticipantID: "local-1",
                activeParticipantIDs: ["local-1", "remote-1"]
            )
        )
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.sessionState == .sharing)
        #expect(controller.sentStates.last?.exerciseName == "Bench Press")
        #expect(controller.sentStates.last?.completedSets == 1)
        #expect(viewModel.participants.count == 2)
    }

    @Test("Participant changes replay local state for late joiners")
    func participantChangesReplayLocalState() async {
        let controller = MockVisionSharePlayWorkoutController()
        let viewModel = VisionSharePlayWorkoutViewModel(controller: controller)
        viewModel.exerciseName = "Squat"

        controller.yield(
            .sessionJoined(
                localParticipantID: "local-1",
                activeParticipantIDs: ["local-1"]
            )
        )
        try? await Task.sleep(for: .milliseconds(100))
        let baselineSendCount = controller.sentStates.count

        controller.yield(
            .participantsChanged(
                localParticipantID: "local-1",
                activeParticipantIDs: ["local-1", "remote-1", "remote-2"]
            )
        )
        try? await Task.sleep(for: .milliseconds(100))

        #expect(controller.sentStates.count == baselineSendCount + 1)
        #expect(viewModel.participants.count == 3)
        #expect(viewModel.participants[1].isPlaceholder)
        #expect(viewModel.participants[2].isPlaceholder)
    }

    @Test("Remote messages merge into the participant board")
    func remoteMessagesMergeIntoBoard() async {
        let controller = MockVisionSharePlayWorkoutController()
        let viewModel = VisionSharePlayWorkoutViewModel(controller: controller)

        controller.yield(
            .sessionJoined(
                localParticipantID: "local-1",
                activeParticipantIDs: ["local-1", "remote-1"]
            )
        )
        controller.yield(
            .receivedState(
                VisionSharePlayWorkoutState(
                    exerciseName: "Deadlift",
                    completedSets: 3,
                    targetReps: 5,
                    phase: .lifting,
                    updatedAt: Date()
                ),
                participantID: "remote-1"
            )
        )
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.participants.count == 2)
        #expect(viewModel.participants[1].title.contains("2"))
        #expect(viewModel.participants[1].exerciseName == "Deadlift")
        #expect(viewModel.participants[1].completedSets == 3)
        #expect(viewModel.participants[1].phase == .lifting)
    }

    @Test("Invalidation returns the board to local-only mode")
    func invalidationResetsRemoteBoard() async {
        let controller = MockVisionSharePlayWorkoutController()
        let viewModel = VisionSharePlayWorkoutViewModel(controller: controller)

        controller.yield(
            .sessionJoined(
                localParticipantID: "local-1",
                activeParticipantIDs: ["local-1", "remote-1"]
            )
        )
        try? await Task.sleep(for: .milliseconds(100))
        controller.yield(.invalidated)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.sessionState == .idle)
        #expect(viewModel.participants.count == 1)
        #expect(viewModel.infoMessage == String(localized: "SharePlay ended. Your workout board is now local only."))
    }
}
