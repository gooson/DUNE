import SwiftUI
import UIKit

/// Routes auxiliary windows back to the primary session that owns the workout.
@MainActor
final class AppWindowRouter: NSObject {
    static let shared = AppWindowRouter()
    nonisolated static let primaryWindowID = "main"
    nonisolated static let insightsWindowID = "workout-insights"

    enum WindowKind: String {
        case primary
        case insights
    }

    private static let kindKey = "com.raftel.dailve.window-kind"
    private static let openerKey = "com.raftel.dailve.window-opener"

    private struct PendingOpen {
        let requestID = UUID()
        let openerID: String
        let existingSessionIDs: Set<String>
    }

    private struct PendingClose {
        let requestID = UUID()
        let insights: UISceneSession
        var primaryID: String?
        let needsRecoveredPrimary: Bool
        var dismissalRequested = false
        var ownerActivationRequested = false
        var ownerActivationGeneration = 0
        let onFailure: @MainActor (String) -> Void
    }

    private var pendingOpen: PendingOpen?
    private var pendingClose: PendingClose?
    private var openTimeout: Timer?
    private var closeTimeout: Timer?
    private var closeReconciliation: Timer?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(sceneDidActivate), name: UIScene.didActivateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(ownerWindowDidBecomeKey), name: UIWindow.didBecomeKeyNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(sceneDidDisconnect), name: UIScene.didDisconnectNotification, object: nil
        )
    }

    func register(_ scene: UIWindowScene, kind: WindowKind) {
        let session = scene.session
        var info = session.userInfo ?? [:]
        info[Self.kindKey] = kind.rawValue
        if kind == .insights, let pendingOpen,
           !pendingOpen.existingSessionIDs.contains(session.persistentIdentifier) {
            info[Self.openerKey] = pendingOpen.openerID
            self.pendingOpen = nil
            openTimeout?.invalidate()
            openTimeout = nil
        }
        session.userInfo = info

        if kind == .primary, pendingClose != nil {
            if pendingClose?.primaryID == nil {
                pendingClose?.primaryID = session.persistentIdentifier
            }
            reconcileClose()
        }
    }

    /// False lets the caller present the existing in-window sheet if attachment is not ready.
    func openInsights(from primary: UISceneSession?, openWindow: OpenWindowAction) -> Bool {
        guard let primary else {
            AppLogger.ui.error("Cannot open Insights window before its primary scene is attached")
            return false
        }
        finishCloseIfDiscarded()
        guard pendingOpen == nil, pendingClose == nil else {
            AppLogger.ui.info("Ignoring duplicate window request while a transition is pending")
            return true
        }
        let existingInsights = UIApplication.shared.openSessions.filter {
            $0.userInfo?[Self.kindKey] as? String == WindowKind.insights.rawValue
        }
        if let existing = existingInsights.first(where: {
            $0.userInfo?[Self.openerKey] as? String == primary.persistentIdentifier
        }) ?? existingInsights.first(where: { $0.scene?.activationState == .foregroundActive })
            ?? existingInsights.sorted(by: { $0.persistentIdentifier < $1.persistentIdentifier }).first {
            // Reusing an Insights session must update its owner before activation.
            // Otherwise Close could return to the workout that opened it earlier.
            var info = existing.userInfo ?? [:]
            info[Self.openerKey] = primary.persistentIdentifier
            existing.userInfo = info
            UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: existing)) { error in
                AppLogger.ui.error("Unable to activate Insights: \(error.localizedDescription)")
            }
            return true
        }
        let request = PendingOpen(
            openerID: primary.persistentIdentifier,
            existingSessionIDs: Set(UIApplication.shared.openSessions.map(\.persistentIdentifier))
        )
        pendingOpen = request
        let requestID = request.requestID
        // This deadline only releases a failed request; it never sequences window transitions.
        openTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pendingOpen?.requestID == requestID else { return }
                self.pendingOpen = nil
                self.openTimeout = nil
                AppLogger.ui.error("Insights window did not attach; another open request is now allowed")
            }
        }
        openWindow(id: Self.insightsWindowID)
        return true
    }

    func closeInsights(
        _ insights: UISceneSession?,
        openWindow: OpenWindowAction,
        dismissWindow: DismissWindowAction,
        onFailure: @escaping @MainActor (String) -> Void
    ) {
        guard let insights else {
            AppLogger.ui.error("Cannot close Insights before its scene is attached")
            onFailure(String(localized: "Unable to return to your workout. Try again."))
            return
        }
        if finishCloseIfDiscarded() == insights.persistentIdentifier { return }
        guard pendingClose == nil else {
            AppLogger.ui.info("Ignoring duplicate Insights close request")
            return
        }
        let primaries = UIApplication.shared.openSessions.filter {
            $0.persistentIdentifier != insights.persistentIdentifier
                && $0.userInfo?[Self.kindKey] as? String == WindowKind.primary.rawValue
        }
        let openerID = insights.userInfo?[Self.openerKey] as? String
        // Prefer the originating workout, then an active primary, then a stable persisted session.
        let primary = primaries.first { $0.persistentIdentifier == openerID }
            ?? primaries.first { $0.scene?.activationState == .foregroundActive }
            ?? primaries.sorted { $0.persistentIdentifier < $1.persistentIdentifier }.first
        if UIDevice.current.userInterfaceIdiom == .phone {
            // UIKit scene activation rejects the phone idiom even when SwiftUI
            // supports windows. Dismiss only this auxiliary scene through SwiftUI.
            if primary == nil {
                openWindow(id: Self.primaryWindowID)
            }
            dismissWindow()
            return
        }
        let request = PendingClose(
            insights: insights, primaryID: primary?.persistentIdentifier,
            needsRecoveredPrimary: primary == nil, onFailure: onFailure
        )
        pendingClose = request
        logClose("started", request)
        let requestID = request.requestID
        closeTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, let current = self.pendingClose, current.requestID == requestID else { return }
                // The deadline only observes and settles; it must not initiate a new scene operation.
                let observation = self.observeClose(current)
                if current.dismissalRequested && !observation.auxiliaryOpen && observation.ownerActive {
                    self.logClose("session discarded and owner active", current)
                    self.clearClose()
                    return
                }
                self.logClose(observation.auxiliaryOpen ? "deadline waiting for session removal" : "deadline waiting for owner activation", current)
                self.failClose(requestID: requestID,
                               message: String(localized: "Unable to return to your workout. Try again."),
                               auxiliaryOpen: observation.auxiliaryOpen)
            }
        }
        // UIKit can disconnect a scene before openSessions drops its archived session.
        // Recheck membership within the original single deadline, keyed to this request.
        closeReconciliation = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pendingClose?.requestID == requestID else { return }
                self.reconcileClose()
            }
        }
        if primary == nil {
            // Do not discard the only usable window until a replacement owner is active.
            openWindow(id: Self.primaryWindowID)
        } else {
            requestInsightsDestruction(requestID: requestID)
        }
    }

    private func activatePrimary(_ session: UISceneSession) {
        guard var request = pendingClose, !request.ownerActivationRequested,
              request.primaryID == session.persistentIdentifier,
              session.persistentIdentifier != request.insights.persistentIdentifier else { return }
        request.ownerActivationRequested = true
        request.ownerActivationGeneration += 1
        pendingClose = request
        let requestID = request.requestID
        let generation = request.ownerActivationGeneration
        let ownerID = session.persistentIdentifier
        logClose("request owner activation", request)
        UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: session)) { [weak self] error in
            Task { @MainActor in
                guard let self, let current = self.pendingClose, current.requestID == requestID,
                      current.primaryID == ownerID, current.ownerActivationRequested,
                      current.ownerActivationGeneration == generation else { return }
                let observation = self.observeClose(current)
                if observation.ownerActive {
                    self.reconcileClose()
                    return
                }
                self.logClose("owner activation error", current)
                self.failClose(requestID: requestID, message: error.localizedDescription,
                               auxiliaryOpen: observation.auxiliaryOpen)
            }
        }
    }

    private func requestInsightsDestruction(requestID: UUID) {
        guard var request = pendingClose, request.requestID == requestID,
              !request.dismissalRequested, let ownerID = request.primaryID,
              ownerID != request.insights.persistentIdentifier else { return }
        request.dismissalRequested = true
        request.ownerActivationRequested = false
        pendingClose = request
        let auxiliaryID = request.insights.persistentIdentifier
        logClose("request Insights session destruction", request)
        UIApplication.shared.requestSceneSessionDestruction(request.insights, options: nil) { [weak self] error in
            Task { @MainActor in
                guard let self, let current = self.pendingClose, current.requestID == requestID,
                      current.dismissalRequested,
                      current.insights.persistentIdentifier == auxiliaryID else { return }
                let observation = self.observeClose(current)
                if !observation.auxiliaryOpen {
                    self.reconcileClose()
                    return
                }
                self.logClose("Insights session destruction error", current)
                self.failClose(requestID: requestID, message: error.localizedDescription,
                               auxiliaryOpen: observation.auxiliaryOpen)
            }
        }
    }

    @objc private func sceneDidActivate(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene, let request = pendingClose,
              scene.session.persistentIdentifier == request.primaryID else { return }
        logClose("owner activated", request)
        reconcileClose()
    }

    @objc private func ownerWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? UIWindow, window.windowLevel == .normal,
              let scene = window.windowScene, let request = pendingClose,
              scene.session.persistentIdentifier == request.primaryID else { return }
        logClose("owner window became key", request)
        reconcileClose()
    }

    @objc private func sceneDidDisconnect(_ notification: Notification) {
        guard let scene = notification.object as? UIScene, let request = pendingClose,
              request.dismissalRequested,
              scene.session.persistentIdentifier == request.insights.persistentIdentifier else { return }
        logClose("auxiliary disconnected", request)
        let requestID = request.requestID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingClose?.requestID == requestID else { return }
            self.reconcileClose()
        }
    }

    private struct CloseObservation {
        let auxiliaryOpen: Bool
        let ownerActive: Bool
        let owner: UISceneSession?
    }

    private func observeClose(_ request: PendingClose) -> CloseObservation {
        let ownerID = request.primaryID
        let sessions = UIApplication.shared.openSessions
        let owner = sessions.first { $0.persistentIdentifier == ownerID }
        let ownerActive = ownerID != nil && ownerID != request.insights.persistentIdentifier
            && UIApplication.shared.connectedScenes.contains {
                $0.session.persistentIdentifier == ownerID && $0.activationState == .foregroundActive
            }
        return CloseObservation(
            auxiliaryOpen: sessions.contains { $0.persistentIdentifier == request.insights.persistentIdentifier },
            ownerActive: ownerActive,
            owner: owner
        )
    }

    // A disconnect alone does not prove that UIKit removed the session from openSessions.
    @discardableResult
    private func reconcileClose() -> String? {
        guard let request = pendingClose, let ownerID = request.primaryID,
              ownerID != request.insights.persistentIdentifier else { return nil }
        let observation = observeClose(request)
        if !request.dismissalRequested {
            // Only the no-owner recovery path waits for a newly created active primary.
            if request.needsRecoveredPrimary && !observation.ownerActive {
                if let owner = observation.owner { activatePrimary(owner) }
                return nil
            }
            requestInsightsDestruction(requestID: request.requestID)
            return nil
        }
        guard !observation.auxiliaryOpen else { return nil }
        if observation.ownerActive {
            let auxiliaryID = request.insights.persistentIdentifier
            logClose("session discarded and owner active", request)
            clearClose()
            return auxiliaryID
        }
        if let owner = observation.owner { activatePrimary(owner) }
        return nil
    }

    // Observation-only terminal check for callers that must not begin a scene operation.
    @discardableResult
    private func finishCloseIfDiscarded() -> String? {
        guard let request = pendingClose, request.dismissalRequested else { return nil }
        let observation = observeClose(request)
        guard !observation.auxiliaryOpen && observation.ownerActive else { return nil }
        let auxiliaryID = request.insights.persistentIdentifier
        logClose("session discarded and owner active", request)
        clearClose()
        return auxiliaryID
    }

    private func logClose(_ event: String, _ request: PendingClose) {
        let owner = request.primaryID ?? "unassigned"
        let ownerState = UIApplication.shared.connectedScenes.first {
            $0.session.persistentIdentifier == owner
        }?.activationState.rawValue ?? UIScene.ActivationState.unattached.rawValue
        let auxiliary = request.insights.persistentIdentifier
        let auxiliaryState = request.insights.scene?.activationState.rawValue ?? UIScene.ActivationState.unattached.rawValue
        AppLogger.ui.info(
            "Insights close \(event, privacy: .public) request=\(request.requestID.uuidString, privacy: .public) owner=\(owner, privacy: .private(mask: .hash)) ownerState=\(ownerState) insights=\(auxiliary, privacy: .private(mask: .hash)) auxiliaryState=\(auxiliaryState) dismissalRequested=\(request.dismissalRequested)"
        )
    }

    private func failClose(requestID: UUID, message: String, auxiliaryOpen: Bool? = nil) {
        guard let request = pendingClose, request.requestID == requestID else { return }
        let canPresentInInsights = auxiliaryOpen ?? observeClose(request).auxiliaryOpen
        AppLogger.ui.error("Unable to return from Insights: \(message)")
        if !canPresentInInsights {
            // The originating view is gone; retain the exact owner/phase in diagnostics.
            logClose("failure after Insights session removal", request)
        }
        clearClose()
        if canPresentInInsights { request.onFailure(message) }
    }

    private func clearClose() {
        closeTimeout?.invalidate()
        closeTimeout = nil
        closeReconciliation?.invalidate()
        closeReconciliation = nil
        pendingClose = nil
    }
}

/// Reads the scene owning this view, rather than choosing an arbitrary application window.
struct AppWindowSceneReader: UIViewRepresentable {
    var kind: AppWindowRouter.WindowKind?
    var onSession: @MainActor (UISceneSession) -> Void = { _ in }

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.isUserInteractionEnabled = false
        view.kind = kind
        view.onSession = onSession
        return view
    }

    func updateUIView(_ view: AttachmentView, context: Context) {
        view.kind = kind
        view.onSession = onSession
        view.resolveScene()
    }

    final class AttachmentView: UIView {
        var kind: AppWindowRouter.WindowKind?
        var onSession: (@MainActor (UISceneSession) -> Void)?
        private var registeredID: String?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { registeredID = nil }
            resolveScene()
        }

        func resolveScene() {
            // Avoid publishing SwiftUI state from inside a representable update.
            DispatchQueue.main.async { [weak self] in
                guard let self, let scene = self.window?.windowScene,
                      self.registeredID != scene.session.persistentIdentifier else { return }
                self.registeredID = scene.session.persistentIdentifier
                if let kind = self.kind { AppWindowRouter.shared.register(scene, kind: kind) }
                self.onSession?(scene.session)
            }
        }
    }
}
