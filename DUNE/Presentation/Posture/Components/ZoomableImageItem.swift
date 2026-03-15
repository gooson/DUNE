import UIKit

/// Data model for the zoomable posture image sheet.
struct ZoomableImageItem: Identifiable {
    let id = UUID()
    let uiImage: UIImage
    let joints: [JointPosition3D]
    let metrics: [PostureMetricResult]
    let captureType: PostureCaptureType
    let label: String

    /// Convenience factory that derives label from capture type.
    static func make(
        uiImage: UIImage,
        joints: [JointPosition3D],
        metrics: [PostureMetricResult],
        captureType: PostureCaptureType
    ) -> ZoomableImageItem {
        ZoomableImageItem(
            uiImage: uiImage,
            joints: joints,
            metrics: metrics,
            captureType: captureType,
            label: captureType == .front
                ? String(localized: "Front")
                : String(localized: "Side")
        )
    }
}
