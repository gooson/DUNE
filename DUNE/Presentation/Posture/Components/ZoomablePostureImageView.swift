import SwiftUI

// MARK: - Posture Image Orientation Correction

extension UIImage {
    /// Whether this posture image has incorrect landscape orientation
    /// (old capture pipeline baked landscape pixels without EXIF metadata).
    var needsPostureOrientationCorrection: Bool {
        size.width > size.height
    }

    /// Corrects orientation for posture photos saved by the old capture pipeline.
    /// Old code used `UIImage(cgImage:)` which discards EXIF orientation metadata,
    /// baking landscape pixels for portrait front-camera captures.
    /// Detects landscape dimensions and rotates 90° CW to restore portrait.
    var postureOrientationCorrected: UIImage {
        guard needsPostureOrientationCorrection, let cgImage else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .right)
    }
}

/// Transforms joint positions from original landscape coordinate space
/// to corrected portrait coordinate space (90° CW rotation).
/// Vision normalized coords: origin bottom-left, Y up.
/// Transform: new_imageX = old_imageY, new_imageY = 1 - old_imageX
func postureOrientationCorrectedJoints(_ joints: [JointPosition3D]) -> [JointPosition3D] {
    joints.map { joint in
        JointPosition3D(
            name: joint.name,
            x: joint.x, y: joint.y, z: joint.z,
            imageX: joint.imageY,
            imageY: joint.imageX.map { 1.0 - $0 }
        )
    }
}

// MARK: - Zoomable Image Item

struct ZoomableImageItem: Identifiable {
    let id = UUID()
    let uiImage: UIImage
    let joints: [JointPosition3D]
    let metrics: [PostureMetricResult]
    let captureType: PostureCaptureType
    let label: String
}

// MARK: - View Modifier

extension View {
    func postureImageZoom(_ item: Binding<ZoomableImageItem?>) -> some View {
        sheet(item: item) { zoomItem in
            ZoomablePostureImageView(
                uiImage: zoomItem.uiImage,
                joints: zoomItem.joints,
                metrics: zoomItem.metrics,
                captureType: zoomItem.captureType,
                label: zoomItem.label
            )
        }
    }
}

// MARK: - Zoomable View

struct ZoomablePostureImageView: View {
    let uiImage: UIImage
    let joints: [JointPosition3D]
    let metrics: [PostureMetricResult]
    let captureType: PostureCaptureType
    let label: String

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let fittedSize = computeFittedSize(
                    imageSize: uiImage.size,
                    containerSize: geometry.size
                )

                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        if !joints.isEmpty {
                            JointOverlayView(
                                jointPositions: joints,
                                imageSize: uiImage.size,
                                metrics: metrics,
                                captureType: captureType
                            )
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, minScale), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale <= minScale {
                                        withAnimation(.spring(duration: 0.3)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    guard scale > minScale else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                    clampOffset(fittedSize: fittedSize, containerSize: geometry.size)
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            if scale > minScale {
                                scale = minScale
                                lastScale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 3.0
                                lastScale = 3.0
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(.black)
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                    }
                    .tint(.white)
                }
            }
        }
    }

    private func computeFittedSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        if imageAspect > containerAspect {
            return CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
        } else {
            return CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
        }
    }

    private func clampOffset(fittedSize: CGSize, containerSize: CGSize) {
        let scaledWidth = fittedSize.width * scale
        let scaledHeight = fittedSize.height * scale
        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        withAnimation(.spring(duration: 0.3)) {
            offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
            offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
            lastOffset = offset
        }
    }
}
