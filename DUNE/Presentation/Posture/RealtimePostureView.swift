#if !os(visionOS)
import AVFoundation
import SwiftUI

/// Realtime posture analysis view with continuous skeleton + angle overlay.
struct RealtimePostureView: View {
    @State private var viewModel = RealtimePostureViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Camera preview
                if viewModel.isActive {
                    CameraPreviewView(
                        session: viewModel.captureSession,
                        captureDevice: viewModel.captureServiceDevice,
                        isMirrored: viewModel.cameraPosition == .front,
                        deviceOrientation: viewModel.deviceOrientation,
                        onPreviewRotationAngleChange: viewModel.updatePreviewRotationAngle
                    )
                    .ignoresSafeArea()
                } else {
                    cameraUnavailable
                }

                // Skeleton overlay (reuse existing BodyGuideOverlay)
                if viewModel.isActive, !viewModel.skeletonKeypoints.isEmpty {
                    BodyGuideOverlay(
                        captureType: .front,
                        guidanceState: viewModel.guidanceState,
                        skeletonKeypoints: viewModel.skeletonKeypoints,
                        sourceImageSize: viewModel.skeletonImageSize,
                        isFrontCamera: viewModel.cameraPosition == .front
                    )
                }

                // Angle overlay
                if viewModel.isActive, !viewModel.currentAngles.isEmpty {
                    AngleOverlay(
                        angles: viewModel.currentAngles,
                        keypoints: viewModel.skeletonKeypoints,
                        isFrontCamera: viewModel.cameraPosition == .front
                    )
                }

                // Score badge (top-left) + exercise mode button (top-right area)
                VStack {
                    HStack {
                        if viewModel.isActive {
                            RealtimeScoreBadge(
                                score: viewModel.smoothedScore,
                                is3DActive: viewModel.is3DActive
                            )
                        }
                        Spacer()
                        exerciseModeButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Form check overlay (when exercise selected)
                    if viewModel.isActive, let formState = viewModel.formState,
                       let exercise = viewModel.selectedExercise {
                        FormCheckOverlay(
                            formState: formState,
                            exerciseName: LocalizedStringKey(exercise.displayName)
                        )
                        .padding(.bottom, 80)
                    }

                    // Guidance hint when no body detected
                    if viewModel.isActive, let hint = viewModel.guidanceState.primaryHint {
                        Text(hint.displayMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, viewModel.isFormMode ? 16 : 80)
                    }
                }
            }
            .navigationTitle("Realtime Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                        .accessibilityIdentifier("realtime-posture-close")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.isActive, viewModel.isFormMode {
                        Button {
                            viewModel.toggleVoiceCoaching()
                        } label: {
                            Image(systemName: viewModel.isVoiceCoachingEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityLabel(Text("Voice coaching"))
                    }

                    Button {
                        viewModel.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(Text("Switch camera"))
                    .disabled(!viewModel.isActive)
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

    private var cameraUnavailable: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Spacer(minLength: 88)

                    VStack(spacing: DS.Spacing.xl) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(palette.heroAccent)
                            .accessibilityHidden(true)

                        Text("Camera is not available")
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("realtime-camera-unavailable")

                        Button("Try Again") {
                            viewModel.stop()
                            viewModel.start()
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(theme.prominentButtonForegroundColor(for: colorScheme))
                        .controlSize(.large)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("realtime-camera-retry")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DS.Spacing.xxl)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xxl))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.xxl)
                            .strokeBorder(palette.border, lineWidth: 1)
                    }
                    .frame(maxWidth: 460)

                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var exerciseModeButton: some View {
        Button {
            viewModel.showExercisePicker = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: viewModel.isFormMode ? "figure.strengthtraining.traditional" : "figure.stand")
                Text(LocalizedStringKey(viewModel.selectedExercise?.displayName ?? "Select Exercise"))
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.md)
            .frame(minHeight: 44)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .accessibilityIdentifier("realtime-exercise-picker-button")
        .accessibilityValue(viewModel.selectedExercise?.exerciseID ?? "general")
    }
}
#endif
