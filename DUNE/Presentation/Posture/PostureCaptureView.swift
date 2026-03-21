#if !os(visionOS)
import AVFoundation
import SwiftUI

struct PostureCaptureView: View {
    @State private var viewModel = PostureAssessmentViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewView(
                    session: viewModel.captureSession,
                    captureDevice: viewModel.captureServiceDevice,
                    isMirrored: viewModel.cameraPosition == .front,
                    deviceOrientation: viewModel.deviceOrientation,
                    onPreviewRotationAngleChange: viewModel.updatePreviewRotationAngle
                )
                .ignoresSafeArea()
                .accessibilityLabel(Text("Camera preview for posture assessment"))

                phaseOverlay
                    .animation(DS.Animation.standard, value: viewModel.capturePhase)
            }
            .navigationTitle("Posture Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    cameraControls
                }
            }
            .task { viewModel.setupCamera() }
            .task { viewModel.updateDeviceOrientation(UIDevice.current.orientation) }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                viewModel.updateDeviceOrientation(UIDevice.current.orientation)
            }
            .onDisappear { viewModel.stopCamera() }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.hapticCountdown)
            .sensoryFeedback(.success, trigger: viewModel.hapticSuccessCount)
            .sensoryFeedback(.error, trigger: viewModel.hapticErrorCount)
        }
    }

    // MARK: - Camera Controls

    @ViewBuilder
    private var cameraControls: some View {
        if case .preparing = viewModel.capturePhase {
            HStack(spacing: 12) {
                // Camera flip button
                Button {
                    viewModel.switchCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.body)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(Text("Switch camera"))

                // Auto/Manual toggle
                Button {
                    viewModel.isAutoCapture.toggle()
                } label: {
                    Image(systemName: viewModel.isAutoCapture ? "a.circle.fill" : "a.circle")
                        .font(.body)
                        .foregroundStyle(viewModel.isAutoCapture ? .green : .white)
                }
                .accessibilityLabel(Text(viewModel.isAutoCapture ? "Auto capture on" : "Auto capture off"))
                .accessibilityHint(Text("Toggle automatic capture when ready"))
            }
        }
    }

    // MARK: - Phase Overlay

    @ViewBuilder
    private var phaseOverlay: some View {
        switch viewModel.capturePhase {
        case .idle:
            Color.black
                .transition(.opacity)
        case .preparing:
            preparingOverlay
                .transition(.opacity)
        case .countdown(let count):
            countdownOverlay(count)
                .transition(.opacity)
        case .capturing, .analyzing:
            analyzingOverlay
                .transition(.opacity)
        case .result:
            resultTransitionOverlay
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .error(let message):
            errorOverlay(message)
                .transition(.opacity)
        }
    }

    // MARK: - Preparing (Real-time Guidance)

    private var preparingOverlay: some View {
        ZStack {
            BodyGuideOverlay(
                captureType: viewModel.captureType,
                guidanceState: viewModel.guidanceState,
                skeletonKeypoints: viewModel.skeletonKeypoints,
                sourceImageSize: viewModel.skeletonImageSize,
                isFrontCamera: viewModel.cameraPosition == .front
            )

            if viewModel.isDiagnosticsEnabled {
                VStack {
                    HStack {
                        diagnosticsOverlay
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.leading, 8)
                .accessibilityHidden(true)
            }

            // Distance indicator (left side)
            HStack {
                DistanceIndicatorView(status: viewModel.guidanceState.distanceStatus)
                    .padding(.leading, 8)
                Spacer()
            }

            VStack {
                // Top: lighting warning
                if viewModel.guidanceState.lightingStatus == .tooLow {
                    lightingWarning
                        .padding(.top, 60)
                }

                Spacer()

                // Checklist (top-left area)
                HStack {
                    Spacer()
                    GuidanceChecklistView(guidanceState: viewModel.guidanceState)
                }
                .padding(.trailing, 8)
                .padding(.bottom, 8)

                // Guidance hint text
                guidanceHintText
                    .padding(.bottom, 8)

                // Capture type label
                Text(viewModel.currentCaptureLabel)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Manual capture button
                Button {
                    viewModel.startCountdown()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        viewModel.guidanceState.isReady ? Color.green : Color.black.opacity(0.2),
                                        lineWidth: 3
                                    )
                            }
                        if viewModel.isAutoCapture && viewModel.guidanceState.isReady {
                            // Pulsing ring when auto-capture is about to trigger
                            Circle()
                                .stroke(.green.opacity(0.5), lineWidth: 2)
                                .frame(width: 84, height: 84)
                        }
                    }
                }
                .accessibilityLabel(Text("Capture photo"))
                .accessibilityHint(Text("Starts a 3-second countdown before capturing"))
                .padding(.bottom, 40)
            }
        }
    }

    private var diagnosticsOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG")
                .font(.caption2.weight(.bold))
            Text("cfg \(viewModel.captureDiagnostics.configuredPreset) / \(viewModel.captureDiagnostics.configuredPixelFormat)")
            Text("preset \(viewModel.captureDiagnostics.sessionPreset)")
            Text(
                "frame \(viewModel.captureDiagnostics.frameWidth)x\(viewModel.captureDiagnostics.frameHeight) \(viewModel.captureDiagnostics.pixelFormat)"
            )
            Text("pose \(viewModel.captureDiagnostics.lastPoseLatencyMs)ms err \(viewModel.captureDiagnostics.poseErrorCount)")
            if let lastVisionError = viewModel.captureDiagnostics.lastVisionError {
                Text(lastVisionError)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                Button {
                    viewModel.cycleDiagnosticsPreset()
                } label: {
                    Text("Preset")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
                .accessibilityIdentifier("posture-diagnostics-preset")

                Button {
                    viewModel.cycleDiagnosticsPixelFormat()
                } label: {
                    Text("Format")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
                .accessibilityIdentifier("posture-diagnostics-format")
            }
            .padding(.top, 2)
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }

    private var lightingWarning: some View {
        Label(
            String(localized: "Low lighting detected"),
            systemImage: "sun.max.trianglebadge.exclamationmark"
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var guidanceHintText: some View {
        Group {
            if let hint = viewModel.guidanceState.primaryHint {
                Text(hint.displayMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if viewModel.guidanceState.isReady {
                Text(viewModel.isAutoCapture
                    ? String(localized: "Hold still — capturing automatically...")
                    : String(localized: "Ready! Tap the button to capture."))
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.guidanceState.primaryHint)
    }

    // MARK: - Countdown

    private func countdownOverlay(_ count: Int) -> some View {
        ZStack {
            BodyGuideOverlay(
                captureType: viewModel.captureType,
                guidanceState: viewModel.guidanceState,
                skeletonKeypoints: viewModel.skeletonKeypoints,
                sourceImageSize: viewModel.skeletonImageSize,
                isFrontCamera: viewModel.cameraPosition == .front
            )

            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .accessibilityLabel(Text("Countdown: \(count)"))
        }
    }

    // MARK: - Analyzing

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)

                Text(String(localized: "Analyzing posture..."))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Result Transition

    private var resultTransitionOverlay: some View {
        PostureResultView(viewModel: viewModel, dismiss: dismiss)
    }

    // MARK: - Error

    private func errorOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7)

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(String(localized: "Try Again")) {
                    viewModel.retakeCurrentCapture()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Error: \(message)"))
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let captureDevice: AVCaptureDevice?
    var isMirrored: Bool = true
    var deviceOrientation: UIDeviceOrientation = .portrait
    var onPreviewRotationAngleChange: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.updatePreview(
            session: session,
            captureDevice: captureDevice,
            isMirrored: isMirrored,
            onPreviewRotationAngleChange: onPreviewRotationAngleChange
        )
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        _ = deviceOrientation
        uiView.updatePreview(
            session: session,
            captureDevice: captureDevice,
            isMirrored: isMirrored,
            onPreviewRotationAngleChange: onPreviewRotationAngleChange
        )
    }
}

final class CameraPreviewUIView: UIView {
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var lastReportedPreviewRotationAngle: CGFloat?
    private var onPreviewRotationAngleChange: ((CGFloat) -> Void)?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func updatePreview(
        session: AVCaptureSession,
        captureDevice: AVCaptureDevice?,
        isMirrored: Bool,
        onPreviewRotationAngleChange: ((CGFloat) -> Void)?
    ) {
        self.onPreviewRotationAngleChange = onPreviewRotationAngleChange
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        if rotationCoordinator?.device !== captureDevice {
            rotationObservation?.invalidate()
            rotationObservation = nil

            rotationCoordinator = captureDevice.map {
                AVCaptureDevice.RotationCoordinator(device: $0, previewLayer: previewLayer)
            }

            // KVO-observe rotation angle so the preview stays upright on Mac
            // (where device orientation changes never retrigger updateUIView).
            rotationObservation = rotationCoordinator?.observe(
                \.videoRotationAngleForHorizonLevelPreview,
                options: [.new, .initial]
            ) { [weak self] _, change in
                let angle = change.newValue ?? 0
                DispatchQueue.main.async { [weak self] in
                    self?.applyRotationAngle(angle)
                }
            }
        }

        guard let connection = previewLayer.connection else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored

        applyRotationAngle(rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 0)
    }

    private func applyRotationAngle(_ angle: CGFloat) {
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle

        if lastReportedPreviewRotationAngle != angle {
            lastReportedPreviewRotationAngle = angle
            onPreviewRotationAngleChange?(angle)
        }
    }
}
#endif
