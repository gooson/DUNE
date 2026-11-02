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
        let dismissWindow: DismissWindowAction
        var dismissalRequested = false
        let onFailure: @MainActor (String) -> Void
    }

    private var pendingOpen: PendingOpen?
    private var pendingClose: PendingClose?
    private var openTimeout: Timer?
    private var closeTimeout: Timer?

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
                activatePrimary(session)
            }
            scheduleDismissalIfPrimaryIsActive()
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
            dismissWindow: dismissWindow, onFailure: onFailure
        )
        pendingClose = request
        logClose("started", request)
        let requestID = request.requestID
        closeTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, let current = self.pendingClose, current.requestID == requestID,
                      self.finishCloseIfDiscarded() == nil else { return }
                self.logClose("deadline", current)
                self.failClose(requestID: requestID, message: String(localized: "Unable to return to your workout. Try again."))
            }
        }
        if let primary {
            activatePrimary(primary)
        } else {
            // openWindow creates an instance; only use it when no registered primary survives.
            openWindow(id: Self.primaryWindowID)
        }
    }

    private func activatePrimary(_ session: UISceneSession) {
        guard let request = pendingClose, request.primaryID == session.persistentIdentifier,
              session.persistentIdentifier != request.insights.persistentIdentifier else { return }
        let requestID = request.requestID
        logClose("request owner activation", request)
        UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: session)) { [weak self] error in
            Task { @MainActor in
                guard let self, let current = self.pendingClose, current.requestID == requestID,
                      !current.dismissalRequested else { return }
                self.logClose("owner activation error", current)
                self.failClose(requestID: requestID, message: error.localizedDescription)
            }
        }
        scheduleDismissalIfPrimaryIsActive()
    }

    private func scheduleDismissalIfPrimaryIsActive() {
        guard let request = pendingClose, !request.dismissalRequested else { return }
        let requestID = request.requestID
        // Let UIKit finish delivering the owner's activation before closing the other window.
        DispatchQueue.main.async { [weak self] in
            guard let self, var current = self.pendingClose, current.requestID == requestID,
                  !current.dismissalRequested, let ownerID = current.primaryID,
                  ownerID != current.insights.persistentIdentifier,
                  UIApplication.shared.connectedScenes.contains(where: {
                      $0.session.persistentIdentifier == ownerID && $0.activationState == .foregroundActive
                  }) else { return }
            current.dismissalRequested = true
            self.pendingClose = current
            self.logClose("invoke Insights window dismissal", current)
            // This environment action came from the Close button in this particular Insights window.
            current.dismissWindow()
        }
    }

    @objc private func sceneDidActivate(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene, let request = pendingClose,
              !request.dismissalRequested, scene.session.persistentIdentifier == request.primaryID else { return }
        logClose("owner activated", request)
        scheduleDismissalIfPrimaryIsActive()
    }

    @objc private func ownerWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? UIWindow, window.windowLevel == .normal,
              let scene = window.windowScene, let request = pendingClose, !request.dismissalRequested,
              scene.session.persistentIdentifier == request.primaryID else { return }
        logClose("owner window became key", request)
        // Key status is local to this scene; the deferred check still requires an active owner.
        scheduleDismissalIfPrimaryIsActive()
    }

    @objc private func sceneDidDisconnect(_ notification: Notification) {
        guard let scene = notification.object as? UIScene,
              let request = pendingClose, request.dismissalRequested,
              scene.session.persistentIdentifier == request.insights.persistentIdentifier else { return }
        logClose("auxiliary disconnected", request)
        let requestID = request.requestID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingClose?.requestID == requestID else { return }
            self.finishCloseIfDiscarded()
        }
    }

    // A disconnected scene can stay archived. Only disappearance of its session confirms removal.
    @discardableResult
    private func finishCloseIfDiscarded() -> String? {
        guard let request = pendingClose, request.dismissalRequested else { return nil }
        let auxiliaryID = request.insights.persistentIdentifier
        guard !UIApplication.shared.openSessions.contains(where: {
            $0.persistentIdentifier == auxiliaryID
        }) else { return nil }
        logClose("session discarded", request)
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

    private func failClose(requestID: UUID, message: String) {
        guard let request = pendingClose, request.requestID == requestID else { return }
        AppLogger.ui.error("Unable to return from Insights: \(message)")
        clearClose()
        request.onFailure(message)
    }

    private func clearClose() {
        closeTimeout?.invalidate()
        closeTimeout = nil
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
