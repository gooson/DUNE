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
    var color: Color
    var shape: Shape
    var opacity: Double = 1.0
    var scale: Double = 1.0

    enum Shape: CaseIterable {
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
}

// MARK: - Particle Factory

enum ConfettiFactory {
    private static let colors: [Color] = [
        DS.Color.activity,
        .yellow,
        .mint,
        .orange,
        .pink,
        .cyan,
    ]

    static func burst(count: Int = 60) -> [ConfettiParticle] {
        (0..<count).map { i in
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
                color: colors[i % colors.count],
                shape: ConfettiParticle.Shape.allCases[i % 3],
                scale: Double.random(in: 0.6...1.0)
            )
        }
    }
}

// MARK: - ViewModifier

private struct ConfettiModifier: ViewModifier {
    let trigger: Int

    @State private var particles: [ConfettiParticle] = []
    @State private var lastTime: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fallback glow for reduce-motion users
    @State private var showGlow = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !particles.isEmpty {
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            for particle in particles {
                                drawParticle(particle, in: context, size: size)
                            }
                        }
                        .allowsHitTesting(false)
                        .onChange(of: timeline.date) { _, now in
                            advanceParticles(now: now)
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
                    particles = ConfettiFactory.burst()
                    lastTime = nil
                }
            }
    }

    private func advanceParticles(now: Date) {
        let dt: Double
        if let last = lastTime {
            dt = min(now.timeIntervalSince(last), 0.05) // cap at 50ms
        } else {
            dt = 0.016
        }
        lastTime = now

        for i in particles.indices.reversed() {
            particles[i].update(dt: dt, gravity: 1.2)
            if particles[i].isExpired {
                particles.remove(at: i)
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

        switch p.shape {
        case .circle:
            let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
            ctx.fill(Path(ellipseIn: rect), with: .color(p.color))

        case .rectangle:
            let rect = CGRect(x: -s / 2, y: -s * 0.3, width: s, height: s * 0.6)
            ctx.fill(Path(rect), with: .color(p.color))

        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: 0, y: -s / 2))
            path.addLine(to: CGPoint(x: -s / 2, y: s / 2))
            path.addLine(to: CGPoint(x: s / 2, y: s / 2))
            path.closeSubpath()
            ctx.fill(path, with: .color(p.color))
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
