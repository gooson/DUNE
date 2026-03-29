import SwiftUI

// MARK: - Particle Model

struct ConfettiParticle: Identifiable {
    let id: Int
    var x: Double
    var y: Double
    var velocityX: Double
    var velocityY: Double
    var rotation: Double
    var rotationSpeed: Double
    let colorIndex: Int
    var particleShape: ParticleShape
    var opacity: Double = 1.0
    var scale: Double = 1.0

    enum ParticleShape: CaseIterable {
        case circle, rectangle, triangle
    }

    /// Advance the particle by one frame (dt seconds).
    mutating func update(dt: Double, gravity: Double) {
        x += velocityX * dt
        y += velocityY * dt
        velocityY += gravity * dt
        velocityX *= (1.0 - 0.3 * dt) // air drag
        rotation += rotationSpeed * dt

        // Fade out in the lower third of travel
        if y > 0.6 {
            opacity = max(0, 1.0 - (y - 0.6) / 0.5)
        }
    }

    var isExpired: Bool { y > 1.2 || opacity <= 0 }

    // MARK: - Factory

    /// Max particle count — bounded for Canvas main-thread performance.
    static func burst(count: Int = 60) -> [ConfettiParticle] {
        let shapes = ParticleShape.allCases
        let colorCount = ConfettiColors.shadings.count
        return (0..<count).map { i in
            let angle = Double.random(in: -Double.pi * 0.8 ... -Double.pi * 0.2)
            let speed = Double.random(in: 0.6...1.4)
            return ConfettiParticle(
                id: i,
                x: Double.random(in: 0.3...0.7),
                y: Double.random(in: 0.15...0.25),
                velocityX: cos(angle) * speed * 0.4,
                velocityY: sin(angle) * speed * 0.6,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -400...400),
                colorIndex: i % colorCount,
                particleShape: shapes[i % shapes.count],
                scale: Double.random(in: 0.6...1.0)
            )
        }
    }
}

// MARK: - Pre-resolved Colors (avoid per-particle Color→Shading resolve)

private enum ConfettiColors {
    static let shadings: [GraphicsContext.Shading] = [
        .color(DS.Color.activity),
        .color(.yellow),
        .color(.mint),
        .color(.orange),
        .color(.pink),
        .color(.cyan),
    ]
}

// MARK: - Pre-resolved Paths (avoid per-frame heap allocation)

private enum ConfettiPaths {
    // Unit-size paths centered at origin; scaled per particle via context transform.
    static let circle = Path(ellipseIn: CGRect(x: -0.5, y: -0.5, width: 1, height: 1))
    static let rectangle = Path(CGRect(x: -0.5, y: -0.3, width: 1, height: 0.6))
    static let triangle: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -0.5))
        p.addLine(to: CGPoint(x: -0.5, y: 0.5))
        p.addLine(to: CGPoint(x: 0.5, y: 0.5))
        p.closeSubpath()
        return p
    }()
}

// MARK: - Particle Store (class-backed to avoid full-body re-renders)

@Observable
private final class ParticleStore {
    var particles: [ConfettiParticle] = []
    var lastTime: Date?

    func advance(now: Date) {
        let dt: Double
        if let last = lastTime {
            dt = min(now.timeIntervalSince(last), 0.05) // cap at 50ms
        } else {
            dt = 0.016
        }
        lastTime = now

        for i in particles.indices {
            particles[i].update(dt: dt, gravity: 1.2)
        }
        particles.removeAll(where: \.isExpired)
    }

    func reset(with newParticles: [ConfettiParticle]) {
        particles = newParticles
        lastTime = nil
    }
}

// MARK: - ViewModifier

private struct ConfettiModifier: ViewModifier {
    let trigger: Int

    @State private var store = ParticleStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fallback glow for reduce-motion users
    @State private var showGlow = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !store.particles.isEmpty {
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            for particle in store.particles {
                                drawParticle(particle, in: context, size: size)
                            }
                        }
                        .allowsHitTesting(false)
                        .onChange(of: timeline.date) { _, now in
                            store.advance(now: now)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .overlay {
                if showGlow {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(.clear)
                        .shadow(color: DS.Color.activity.opacity(0.5), radius: 20)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                if reduceMotion {
                    withAnimation(DS.Animation.emphasize) { showGlow = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.0))
                        withAnimation(DS.Animation.standard) { showGlow = false }
                    }
                } else {
                    store.reset(with: ConfettiParticle.burst())
                }
            }
    }

    private func drawParticle(_ p: ConfettiParticle, in context: GraphicsContext, size: CGSize) {
        let px = p.x * size.width
        let py = p.y * size.height
        let s = 6.0 * p.scale

        var ctx = context
        ctx.opacity = p.opacity
        ctx.translateBy(x: px, y: py)
        ctx.rotate(by: .degrees(p.rotation))
        ctx.scaleBy(x: s, y: s)

        let shading = ConfettiColors.shadings[p.colorIndex]

        switch p.particleShape {
        case .circle:
            ctx.fill(ConfettiPaths.circle, with: shading)
        case .rectangle:
            ctx.fill(ConfettiPaths.rectangle, with: shading)
        case .triangle:
            ctx.fill(ConfettiPaths.triangle, with: shading)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Shows a confetti burst whenever `trigger` increments.
    /// Respects `accessibilityReduceMotion` — shows a subtle glow pulse instead.
    func confetti(trigger: Int) -> some View {
        modifier(ConfettiModifier(trigger: trigger))
    }
}
