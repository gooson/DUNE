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

                // Score badge (top-left) + exercise mode button (top-right area)
                VStack {
                    HStack {
                        RealtimeScoreBadge(
                            score: viewModel.smoothedScore,
                            is3DActive: viewModel.is3DActive
                        )
                        Spacer()
                        exerciseModeButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Form check overlay (when exercise selected)
                    if let formState = viewModel.formState,
                       let exercise = viewModel.selectedExercise {
                        FormCheckOverlay(
                            formState: formState,
                            exerciseName: exercise.displayName
                        )
                        .padding(.bottom, 80)
                    }

                    // Guidance hint when no body detected
                    if let hint = viewModel.guidanceState.primaryHint {
                        Text(hint.displayMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, viewModel.isFormMode ? 16 : 80)
                    }
                }
            }
            .navigationTitle("Realtime Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.isFormMode {
                        Button {
                            viewModel.toggleVoiceCoaching()
                        } label: {
                            Image(systemName: viewModel.isVoiceCoachingEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(Text("Voice coaching"))
                    }

                    Button {
                        viewModel.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(Text("Switch camera"))
                }
            }
            .task {
                viewModel.updateDeviceOrientation(UIDevice.current.orientation)
                viewModel.start()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                viewModel.updateDeviceOrientation(UIDevice.current.orientation)
            }
            .onDisappear { viewModel.stop() }
            .sheet(isPresented: $viewModel.showExercisePicker) {
                ExercisePickerSheet(
                    exercises: ExerciseFormRule.allBuiltIn,
                    selectedExerciseID: viewModel.selectedExercise?.exerciseID,
                    onSelect: viewModel.selectExercise
                )
            }
        }
    }

    private var exerciseModeButton: some View {
        Button {
            viewModel.showExercisePicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isFormMode ? "figure.strengthtraining.traditional" : "figure.stand")
                if let exercise = viewModel.selectedExercise {
                    Text(exercise.displayName)
                        .font(.caption)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
#endif
