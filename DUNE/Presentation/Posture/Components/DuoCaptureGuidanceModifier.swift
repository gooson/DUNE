#if !os(visionOS)
import SwiftUI

/// The system decides whether the second display is available to this camera scene.
struct DuoCaptureGuidanceModifier<Accessory: View>: ViewModifier {
    @Binding var isEnabled: Bool
    @Binding var isAvailable: Bool
    let accessory: Accessory

    @ViewBuilder
    func body(content: Content) -> some View {
        #if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            content.sceneAccessory {
                CameraCaptureAccessory(isEnabled: $isEnabled) {
                    accessory
                }
                .onAvailabilityChange { available in
                    isAvailable = available
                    if !available { isEnabled = false }
                }
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
#endif
