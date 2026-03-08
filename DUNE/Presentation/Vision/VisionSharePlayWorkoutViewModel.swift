import Foundation
import Observation

#if canImport(GroupActivities)
import Combine
import GroupActivities
#endif

enum VisionSharePlayWorkoutPhase: String, CaseIterable, Codable, Sendable {
    case preparing
    case lifting
    case resting
    case done

    var displayName: String {
        switch self {
        case .preparing:
            String(localized: "Preparing")
        case .lifting:
            String(localized: "Lifting")
        case .resting:
            String(localized: "Resting")
        case .done:
            String(localized: "Done")
        }
    }

    var systemImage: String {
        switch self {
        case .preparing:
            "figure.strengthtraining.traditional"
        case .lifting:
            "dumbbell.fill"
        case .resting:
            "timer"
        case .done:
            "checkmark.circle.fill"
        }
    }
}

struct VisionSharePlayWorkoutState: Codable, Equatable, Sendable {
    let exerciseName: String
    let completedSets: Int
    let targetReps: Int
    let phase: VisionSharePlayWorkoutPhase
    let updatedAt: Date
}

struct VisionSharePlayParticipantBoardItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let exerciseName: String
    let completedSets: Int
    let targetReps: Int
    let phase: VisionSharePlayWorkoutPhase
    let isLocal: Bool
    let isPlaceholder: Bool
    let updatedAt: Date?
}

enum VisionSharePlayWorkoutStartResult: Equatable, Sendable {
    case activationRequested
    case activationDisabled
    case cancelled
    case unsupported
    case failed
}

enum VisionSharePlayWorkoutSessionEvent: Equatable, Sendable {
    case sessionJoined(localParticipantID: String, activeParticipantIDs: [String])
    case participantsChanged(localParticipantID: String, activeParticipantIDs: [String])
    case receivedState(VisionSharePlayWorkoutState, participantID: String)
    case invalidated
}

@MainActor
protocol VisionSharePlayWorkoutControlling: AnyObject {
    func startSharing() async -> VisionSharePlayWorkoutStartResult
    func send(_ state: VisionSharePlayWorkoutState) async throws
    func events() -> AsyncStream<VisionSharePlayWorkoutSessionEvent>
}

@Observable
@MainActor
final class VisionSharePlayWorkoutViewModel {
    enum SessionState: Equatable {
        case idle
        case preparing
        case sharing
        case unsupported
        case failed
    }

    var sessionState: SessionState
    var exerciseName: String {
        didSet {
            guard exerciseName != oldValue else { return }
            updateParticipants()
            Task { await self.syncLocalStateIfNeeded() }
        }
    }
    var completedSets: Int
    var targetReps: Int
    var phase: VisionSharePlayWorkoutPhase
    var participants: [VisionSharePlayParticipantBoardItem]
    var infoMessage: String?
    var errorMessage: String?

    private let controller: any VisionSharePlayWorkoutControlling
    private var localParticipantID = "local"
    private var activeRemoteParticipantIDs: [String] = []
    private var remoteStates: [String: VisionSharePlayWorkoutState] = [:]
    private var eventTask: Task<Void, Never>?

    convenience init() {
        self.init(controller: VisionSharePlayWorkoutControllerFactory.makeDefault())
    }

    init(controller: any VisionSharePlayWorkoutControlling) {
        self.controller = controller
        self.sessionState = controller is UnsupportedVisionSharePlayWorkoutController ? .unsupported : .idle
        self.exerciseName = ""
        self.completedSets = 0
        self.targetReps = 8
        self.phase = .preparing
        self.participants = []
        self.infoMessage = controller is UnsupportedVisionSharePlayWorkoutController
            ? String(localized: "SharePlay is not available in this environment.")
            : String(localized: "Prepare your next set, then start SharePlay from a FaceTime call or nearby session.")

        updateParticipants()
        startObservingEvents()
    }

    var canStartSharePlay: Bool {
        switch sessionState {
        case .idle, .failed:
            true
        case .preparing, .sharing, .unsupported:
            false
        }
    }

    var sharePlayButtonTitle: String {
        switch sessionState {
        case .idle, .failed:
            String(localized: "Start SharePlay")
        case .preparing:
            String(localized: "Preparing SharePlay...")
        case .sharing:
            String(localized: "SharePlay Active")
        case .unsupported:
            String(localized: "SharePlay Unavailable")
        }
    }

    var sessionBadgeTitle: String {
        switch sessionState {
        case .idle:
            String(localized: "Local Only")
        case .preparing:
            String(localized: "SharePlay Pending")
        case .sharing:
            String(localized: "SharePlay Live")
        case .unsupported:
            String(localized: "Unavailable")
        case .failed:
            String(localized: "Retry Needed")
        }
    }

    var activeParticipantCount: Int {
        participants.count
    }

    func startSharePlay() async {
        guard canStartSharePlay else { return }

        errorMessage = nil
        sessionState = .preparing

        switch await controller.startSharing() {
        case .activationRequested:
            infoMessage = String(localized: "SharePlay invitation sent. Waiting for the session to connect.")
        case .activationDisabled:
            sessionState = .idle
            infoMessage = String(localized: "SharePlay becomes available during a FaceTime call or nearby session.")
        case .cancelled:
            sessionState = .idle
            infoMessage = String(localized: "SharePlay start was cancelled.")
        case .unsupported:
            sessionState = .unsupported
            infoMessage = String(localized: "SharePlay is not available in this environment.")
        case .failed:
            sessionState = .failed
            errorMessage = String(localized: "SharePlay could not start. Try again.")
        }
    }

    func increaseSets() {
        completedSets += 1
        updateParticipants()
        Task { await self.syncLocalStateIfNeeded() }
    }

    func decreaseSets() {
        guard completedSets > 0 else { return }
        completedSets -= 1
        updateParticipants()
        Task { await self.syncLocalStateIfNeeded() }
    }

    func increaseTargetReps() {
        targetReps = min(targetReps + 1, 30)
        updateParticipants()
        Task { await self.syncLocalStateIfNeeded() }
    }

    func decreaseTargetReps() {
        guard targetReps > 1 else { return }
        targetReps -= 1
        updateParticipants()
        Task { await self.syncLocalStateIfNeeded() }
    }

    func advancePhase() {
        let allCases = VisionSharePlayWorkoutPhase.allCases
        guard let currentIndex = allCases.firstIndex(of: phase) else { return }
        let nextIndex = allCases.index(after: currentIndex)
        phase = nextIndex == allCases.endIndex
            ? allCases[allCases.startIndex]
            : allCases[nextIndex]
        updateParticipants()
        Task { await self.syncLocalStateIfNeeded() }
    }

    private func startObservingEvents() {
        let events = controller.events()
        eventTask = Task { [weak self] in
            for await event in events {
                if Task.isCancelled { break }
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: VisionSharePlayWorkoutSessionEvent) async {
        switch event {
        case .sessionJoined(let localParticipantID, let activeParticipantIDs):
            self.localParticipantID = localParticipantID
            self.sessionState = .sharing
            self.activeRemoteParticipantIDs = activeParticipantIDs
                .filter { $0 != localParticipantID }
                .sorted()
            self.infoMessage = String(localized: "SharePlay connected. Everyone now sees live set updates.")
            self.errorMessage = nil
            self.updateParticipants()
            await syncLocalStateIfNeeded()

        case .participantsChanged(let localParticipantID, let activeParticipantIDs):
            self.localParticipantID = localParticipantID
            self.activeRemoteParticipantIDs = activeParticipantIDs
                .filter { $0 != localParticipantID }
                .sorted()
            remoteStates = remoteStates.filter { activeRemoteParticipantIDs.contains($0.key) }
            updateParticipants()
            await syncLocalStateIfNeeded()

        case .receivedState(let state, let participantID):
            guard participantID != localParticipantID else { return }
            remoteStates[participantID] = state
            updateParticipants()

        case .invalidated:
            sessionState = .idle
            activeRemoteParticipantIDs = []
            remoteStates.removeAll()
            updateParticipants()
            infoMessage = String(localized: "SharePlay ended. Your workout board is now local only.")
        }
    }

    private func syncLocalStateIfNeeded() async {
        guard sessionState == .sharing else { return }

        do {
            try await controller.send(localState)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Live SharePlay update could not be sent.")
        }
    }

    private var localState: VisionSharePlayWorkoutState {
        VisionSharePlayWorkoutState(
            exerciseName: trimmedExerciseName,
            completedSets: completedSets,
            targetReps: targetReps,
            phase: phase,
            updatedAt: Date()
        )
    }

    private var trimmedExerciseName: String {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Workout") : trimmed
    }

    private func updateParticipants() {
        var boardItems = [
            VisionSharePlayParticipantBoardItem(
                id: localParticipantID,
                title: String(localized: "You"),
                exerciseName: trimmedExerciseName,
                completedSets: completedSets,
                targetReps: targetReps,
                phase: phase,
                isLocal: true,
                isPlaceholder: false,
                updatedAt: nil
            )
        ]

        for (index, participantID) in activeRemoteParticipantIDs.enumerated() {
            if let state = remoteStates[participantID] {
                boardItems.append(
                    VisionSharePlayParticipantBoardItem(
                        id: participantID,
                        title: String(localized: "Participant \(index + 2)"),
                        exerciseName: state.exerciseName,
                        completedSets: state.completedSets,
                        targetReps: state.targetReps,
                        phase: state.phase,
                        isLocal: false,
                        isPlaceholder: false,
                        updatedAt: state.updatedAt
                    )
                )
            } else {
                boardItems.append(
                    VisionSharePlayParticipantBoardItem(
                        id: participantID,
                        title: String(localized: "Participant \(index + 2)"),
                        exerciseName: String(localized: "Awaiting update"),
                        completedSets: 0,
                        targetReps: 0,
                        phase: .preparing,
                        isLocal: false,
                        isPlaceholder: true,
                        updatedAt: nil
                    )
                )
            }
        }

        participants = boardItems
    }
}

private enum VisionSharePlayWorkoutControllerFactory {
    @MainActor
    static func makeDefault() -> any VisionSharePlayWorkoutControlling {
        #if canImport(GroupActivities)
        return VisionSharePlayWorkoutController()
        #else
        return UnsupportedVisionSharePlayWorkoutController()
        #endif
    }
}

final class UnsupportedVisionSharePlayWorkoutController: VisionSharePlayWorkoutControlling {
    func startSharing() async -> VisionSharePlayWorkoutStartResult {
        .unsupported
    }

    func send(_ state: VisionSharePlayWorkoutState) async throws {}

    func events() -> AsyncStream<VisionSharePlayWorkoutSessionEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

#if canImport(GroupActivities)
private struct VisionSharePlayWorkoutActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = String(localized: "Workout Board")
        metadata.type = .generic
        return metadata
    }
}

private enum VisionSharePlayWorkoutControllerError: Error {
    case noActiveSession
}

@MainActor
private final class VisionSharePlayWorkoutController: VisionSharePlayWorkoutControlling {
    private let eventStream: AsyncStream<VisionSharePlayWorkoutSessionEvent>
    private let continuation: AsyncStream<VisionSharePlayWorkoutSessionEvent>.Continuation
    private var sessionTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var participantsTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    private var messenger: GroupSessionMessenger?
    private var currentSession: GroupSession<VisionSharePlayWorkoutActivity>?

        init() {
        var streamContinuation: AsyncStream<VisionSharePlayWorkoutSessionEvent>.Continuation?
        self.eventStream = AsyncStream { continuation in
            streamContinuation = continuation
        }
        self.continuation = streamContinuation!

        sessionTask = Task { [weak self] in
            await self?.observeSessions()
        }
    }

    deinit {
        sessionTask?.cancel()
        stateTask?.cancel()
        participantsTask?.cancel()
        messageTask?.cancel()
        continuation.finish()
    }

    func startSharing() async -> VisionSharePlayWorkoutStartResult {
        let activity = VisionSharePlayWorkoutActivity()

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
                return .activationRequested
            } catch {
                return .failed
            }
        case .activationDisabled:
            return .activationDisabled
        case .cancelled:
            return .cancelled
        @unknown default:
            return .failed
        }
    }

    func send(_ state: VisionSharePlayWorkoutState) async throws {
        guard let messenger else {
            throw VisionSharePlayWorkoutControllerError.noActiveSession
        }

        try await messenger.send(state)
    }

    func events() -> AsyncStream<VisionSharePlayWorkoutSessionEvent> {
        eventStream
    }

    private func observeSessions() async {
        for await session in VisionSharePlayWorkoutActivity.sessions() {
            if Task.isCancelled { break }
            await configure(session)
        }
    }

    private func configure(_ session: GroupSession<VisionSharePlayWorkoutActivity>) async {
        stateTask?.cancel()
        participantsTask?.cancel()
        messageTask?.cancel()

        currentSession = session
        messenger = GroupSessionMessenger(session: session)
        session.join()

        let localParticipantID = Self.participantID(for: session.localParticipant)
        continuation.yield(
            .sessionJoined(
                localParticipantID: localParticipantID,
                activeParticipantIDs: session.activeParticipants.map(Self.participantID(for:))
            )
        )

        stateTask = Task { [weak self] in
            for await state in session.$state.values {
                if Task.isCancelled { break }

                switch state {
                case .invalidated:
                    self?.continuation.yield(.invalidated)
                    self?.messenger = nil
                    self?.currentSession = nil
                default:
                    continue
                }
            }
        }

        participantsTask = Task { [weak self] in
            for await participants in session.$activeParticipants.values {
                if Task.isCancelled { break }
                self?.continuation.yield(
                    .participantsChanged(
                        localParticipantID: localParticipantID,
                        activeParticipantIDs: participants.map(Self.participantID(for:))
                    )
                )
            }
        }

        messageTask = Task { [weak self] in
            guard let messenger = self?.messenger else { return }
            for await (message, context) in messenger.messages(of: VisionSharePlayWorkoutState.self) {
                if Task.isCancelled { break }
                self?.continuation.yield(
                    .receivedState(
                        message,
                        participantID: Self.participantID(for: context.source)
                    )
                )
            }
        }
    }

    private static func participantID(for participant: Participant) -> String {
        String(describing: participant.id)
    }
}
#endif
