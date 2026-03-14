import AVFoundation
import SwiftUI

struct PostureCaptureView: View {
    @State private var viewModel = PostureAssessmentViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()
                    .accessibilityLabel(Text("Camera preview for posture assessment"))

                phaseOverlay
            }
            .navigationTitle("Posture Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .task { viewModel.setupCamera() }
            .onDisappear { viewModel.stopCamera() }
        }
    }

    // MARK: - Phase Overlay

    @ViewBuilder
    private var phaseOverlay: some View {
        switch viewModel.capturePhase {
        case .idle:
            Color.black
        case .guiding:
            guidingOverlay
        case .countdown(let count):
            countdownOverlay(count)
        case .capturing, .analyzing:
            analyzingOverlay
        case .result:
            resultTransitionOverlay
        case .error(let message):
            errorOverlay(message)
        }
    }

    // MARK: - Guiding

    private var guidingOverlay: some View {
        ZStack {
            BodyGuideOverlay(captureType: viewModel.captureType)

            VStack {
                Spacer()

                Text(viewModel.currentCaptureLabel)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text(guidingInstructionText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                Button {
                    viewModel.startCountdown()
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Circle()
                                .strokeBorder(.black.opacity(0.2), lineWidth: 3)
                        }
                }
                .accessibilityLabel(Text("Capture photo"))
                .accessibilityHint(Text("Starts a 3-second countdown before capturing"))
                .padding(.bottom, 40)
            }
        }
    }

    private var guidingInstructionText: String {
        switch viewModel.captureType {
        case .front:
            String(localized: "Stand facing the camera with your full body visible. Keep your arms relaxed at your sides.")
        case .side:
            String(localized: "Turn to show your side profile. Keep your arms relaxed and stand naturally.")
        }
    }

    // MARK: - Countdown

    private func countdownOverlay(_ count: Int) -> some View {
        ZStack {
            BodyGuideOverlay(captureType: viewModel.captureType)

            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: count)
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

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
