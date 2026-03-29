import Testing
@testable import DUNE

@Suite("ConfettiModifier")
struct ConfettiModifierTests {

    // MARK: - Particle Factory

    @Test("burst creates expected particle count")
    func burstCreatesExpectedCount() {
        let particles = ConfettiFactory.burst(count: 60)
        #expect(particles.count == 60)
    }

    @Test("burst creates particles with unique IDs")
    func burstCreatesUniqueIDs() {
        let particles = ConfettiFactory.burst(count: 30)
        let ids = Set(particles.map(\.id))
        #expect(ids.count == 30)
    }

    @Test("burst with zero count creates no particles")
    func burstZeroCount() {
        let particles = ConfettiFactory.burst(count: 0)
        #expect(particles.isEmpty)
    }

    @Test("all shape types represented in burst")
    func allShapesRepresented() {
        let particles = ConfettiFactory.burst(count: 9)
        let shapes = Set(particles.map(\.shape))
        #expect(shapes.count == 3)
    }

    // MARK: - Particle Physics

    @Test("particle velocity increases downward with gravity")
    func particleGravityEffect() {
        var particle = ConfettiFactory.burst(count: 1)[0]
        let initialVelocityY = particle.velocityY
        particle.update(dt: 0.1, gravity: 1.2)
        // Gravity adds positive (downward) velocity each frame
        #expect(particle.velocityY > initialVelocityY)
    }

    @Test("particle expires when below screen")
    func particleExpiresWhenBelowScreen() {
        var particle = ConfettiFactory.burst(count: 1)[0]
        // Force particle well below screen
        particle.y = 1.3
        particle.opacity = 0
        #expect(particle.isExpired)
    }

    @Test("particle not expired at start")
    func particleNotExpiredAtStart() {
        let particle = ConfettiFactory.burst(count: 1)[0]
        #expect(!particle.isExpired)
    }

    @Test("particle fades after passing 60% of height")
    func particleFadesInLowerThird() {
        var particle = ConfettiFactory.burst(count: 1)[0]
        particle.y = 0.8
        particle.update(dt: 0.001, gravity: 0)
        #expect(particle.opacity < 1.0)
    }

    @Test("particle rotation changes over time")
    func particleRotationChanges() {
        var particle = ConfettiFactory.burst(count: 1)[0]
        let initialRotation = particle.rotation
        particle.update(dt: 0.1, gravity: 1.2)
        #expect(particle.rotation != initialRotation)
    }

    @Test("particle eventually expires through normal physics")
    func particleEventuallyExpires() {
        var particle = ConfettiFactory.burst(count: 1)[0]
        // Simulate ~3 seconds of physics at 60fps
        for _ in 0..<180 {
            particle.update(dt: 1.0 / 60.0, gravity: 1.2)
            if particle.isExpired { break }
        }
        #expect(particle.isExpired)
    }
}
