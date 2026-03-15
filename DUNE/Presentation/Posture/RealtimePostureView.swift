#if !os(visionOS)
import AVFoundation
import SwiftUI

/// Realtime posture analysis view with continuous skeleton + angle overlay.
struct RealtimePostureView: View {
    @State private var viewModel = RealtimePostureViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(
                    session: viewModel.captureSession,
                    captureDevice: viewModel.captureServiceDevice,
                    isMirrored: viewModel.cameraPosition == .front,
                    deviceOrientation: viewModel.deviceOrientation,
                    onPreviewRotationAngleChange: viewModel.updatePreviewRotationAngle
                )
                .ignoresSafeArea()

                // Skeleton overlay (reuse existing BodyGuideOverlay)
                if !viewModel.skeletonKeypoints.isEmpty {
                    BodyGuideOverlay(
                        captureType: .front,
                        guidanceState: viewModel.guidanceState,
                        skeletonKeypoints: viewModel.skeletonKeypoints,
                        sourceImageSize: viewModel.skeletonImageSize,
                        isFrontCamera: viewModel.cameraPosition == .front
                    )
                }

                // Angle overlay
                if !viewModel.currentAngles.isEmpty {
                    AngleOverlay(
                        angles: viewModel.currentAngles,
                        keypoints: viewModel.skeletonKeypoints,
                        isFrontCamera: viewModel.cameraPosition == .front
                    )
                }

                // Score badge (top-left)
                VStack {
                    HStack {
                        RealtimeScoreBadge(
                            score: viewModel.smoothedScore,
                            is3DActive: viewModel.is3DActive
                        )
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Guidance hint when no body detected
                    if let hint = viewModel.guidanceState.primaryHint {
                        Text(hint.displayMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Realtime Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(Text("Switch camera"))
                }
            }
            .task { viewModel.updateDeviceOrientation(UIDevice.current.orientation) }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                viewModel.updateDeviceOrientation(UIDevice.current.orientation)
            }
            .task { viewModel.start() }
            .onDisappear { viewModel.stop() }
        }
    }
}
#endif
