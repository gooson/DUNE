import AVFoundation
import SwiftUI
import UIKit

struct ArtistThemeBackground: View {
    enum Placement { case tab, detail, sheet }

    let edition: ArtistThemeEdition
    let placement: Placement

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.waveReducedMotion) private var reducedMotion
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    static func playsMotion(visible: Bool, phase: ScenePhase, reduced: Bool, lowPower: Bool) -> Bool {
        visible && phase == .active && !reduced && !lowPower
    }

    var body: some View {
        let ground = edition.ground(for: scheme)
        GeometryReader { proxy in
            let maximum: CGFloat = switch placement {
            case .tab: 228
            case .detail: 197
            case .sheet: 132
            }
            let height = min(proxy.size.height, maximum, max(118, proxy.size.width * 0.47))
            ZStack(alignment: .top) {
                ground
                ZStack {
                    if let image = edition.poster {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: proxy.size.width, height: height).clipped()
                    }
                    // A sheet can share the window with a still-visible animated tab.
                    if placement != .sheet && Self.playsMotion(visible: visible, phase: scenePhase, reduced: reducedMotion, lowPower: lowPower) {
                        ArtistMotionPlayer(url: edition.movieURL)
                    }
                }
                .frame(width: proxy.size.width, height: height)
                .clipped()
                .opacity(scheme == .dark ? 0.70 : 0.96)
                .overlay {
                    LinearGradient(stops: [
                        .init(color: ground.opacity(0.93), location: 0),
                        .init(color: ground.opacity(0.58), location: 0.32),
                        .init(color: .clear, location: 0.68)
                    ], startPoint: .leading, endPoint: .trailing)
                }
                .overlay {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.69),
                        .init(color: ground, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

/// Only the decorative artwork is video. A poster under the transparent layer
/// remains available during the first decode and in static previews.
private struct ArtistMotionPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> ArtistPlayerView { ArtistPlayerView() }
    func updateUIView(_ view: ArtistPlayerView, context: Context) { view.configure(url: url) }
    static func dismantleUIView(_ view: ArtistPlayerView, coordinator: ()) { view.stop() }
}

private final class ArtistPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var movieLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    private var url: URL?
    private var queue: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var readyObservation: NSKeyValueObservation?

    func configure(url: URL) {
        if self.url != url {
            stop()
            self.url = url
        }
        startIfVisible()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else { startIfVisible() }
    }

    private func startIfVisible() {
        guard window != nil, queue == nil, let url, let movieLayer else { return }
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        isUserInteractionEnabled = false
        isOpaque = false
        movieLayer.opacity = 0
        movieLayer.videoGravity = .resizeAspectFill
        movieLayer.player = player
        queue = player
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        readyObservation = movieLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let layer = self?.movieLayer, layer.isReadyForDisplay else { return }
                layer.opacity = 1
            }
        }
        player.play()
    }

    func stop() {
        readyObservation = nil
        queue?.pause()
        looper?.disableLooping()
        looper = nil
        movieLayer?.player = nil
        queue?.removeAllItems()
        queue = nil
    }
}
