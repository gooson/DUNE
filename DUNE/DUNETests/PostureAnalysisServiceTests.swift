import Foundation
import Testing

@testable import DUNE

@Suite("PostureAnalysisService")
struct PostureAnalysisServiceTests {

    let service = PostureAnalysisService()

    // MARK: - Helper

    private func joint(_ name: String, x: Float, y: Float, z: Float) -> JointPosition3D {
        JointPosition3D(name: name, x: x, y: y, z: z)
    }

    /// Create a set of joints with perfect upright posture.
    private var perfectFrontJoints: [JointPosition3D] {
        [
            joint("centerHead", x: 0, y: 1.7, z: 0),
            joint("centerShoulder", x: 0, y: 1.4, z: 0),
            joint("leftShoulder", x: -0.2, y: 1.4, z: 0),
            joint("rightShoulder", x: 0.2, y: 1.4, z: 0),
            joint("spine", x: 0, y: 1.1, z: 0),
            joint("root", x: 0, y: 0.9, z: 0),
            joint("leftHip", x: -0.12, y: 0.9, z: 0),
            joint("rightHip", x: 0.12, y: 0.9, z: 0),
            joint("leftKnee", x: -0.12, y: 0.5, z: 0),
            joint("rightKnee", x: 0.12, y: 0.5, z: 0),
            joint("leftAnkle", x: -0.12, y: 0.05, z: 0),
            joint("rightAnkle", x: 0.12, y: 0.05, z: 0),
        ]
    }

    private var perfectSideJoints: [JointPosition3D] {
        [
            joint("centerHead", x: 0, y: 1.7, z: 0),
            joint("topHead", x: 0, y: 1.8, z: 0),
            joint("centerShoulder", x: 0, y: 1.4, z: 0),
            joint("leftShoulder", x: 0, y: 1.4, z: -0.01),
            joint("rightShoulder", x: 0, y: 1.4, z: 0.01),
            joint("spine", x: 0, y: 1.1, z: 0),
            joint("root", x: 0, y: 0.9, z: 0),
            joint("leftHip", x: 0, y: 0.9, z: -0.01),
            joint("rightHip", x: 0, y: 0.9, z: 0.01),
            joint("leftKnee", x: 0, y: 0.5, z: 0),
            joint("rightKnee", x: 0, y: 0.5, z: 0),
            joint("leftAnkle", x: 0, y: 0.05, z: 0),
            joint("rightAnkle", x: 0, y: 0.05, z: 0),
        ]
    }

    // MARK: - Front View Tests

    @Test("Perfect front posture yields all normal metrics")
    func perfectFrontPosture() {
        let results = service.analyzeFrontView(joints: perfectFrontJoints)

        for metric in results {
            #expect(metric.status == .normal, "Metric \(metric.type) should be normal, got \(metric.status)")
        }
    }

    @Test("Shoulder asymmetry detected with uneven shoulders")
    func shoulderAsymmetry() {
        var joints = perfectFrontJoints
        // Make left shoulder 4cm higher
        if let idx = joints.firstIndex(where: { $0.name == "leftShoulder" }) {
            joints[idx] = joint("leftShoulder", x: -0.2, y: 1.44, z: 0)
        }

        let results = service.analyzeFrontView(joints: joints)
        let shoulderMetric = results.first { $0.type == .shoulderAsymmetry }

        #expect(shoulderMetric != nil)
        #expect(shoulderMetric?.status == .caution || shoulderMetric?.status == .warning)
        #expect(shoulderMetric!.value > 3.0, "Expected > 3cm asymmetry")
    }

    @Test("Hip asymmetry detected with uneven hips")
    func hipAsymmetry() {
        var joints = perfectFrontJoints
        if let idx = joints.firstIndex(where: { $0.name == "leftHip" }) {
            joints[idx] = joint("leftHip", x: -0.12, y: 0.94, z: 0)
        }

        let results = service.analyzeFrontView(joints: joints)
        let hipMetric = results.first { $0.type == .hipAsymmetry }

        #expect(hipMetric != nil)
        #expect(hipMetric!.value > 3.0)
    }

    @Test("Lateral shift detected when head is off-center")
    func lateralShift() {
        var joints = perfectFrontJoints
        if let idx = joints.firstIndex(where: { $0.name == "centerHead" }) {
            joints[idx] = joint("centerHead", x: 0.05, y: 1.7, z: 0)
        }

        let results = service.analyzeFrontView(joints: joints)
        let shiftMetric = results.first { $0.type == .lateralShift }

        #expect(shiftMetric != nil)
        #expect(shiftMetric!.value > 3.0)
    }

    @Test("Missing frontal joints yield unmeasurable results")
    func missingFrontJoints() {
        let results = service.analyzeFrontView(joints: [])

        for metric in results {
            #expect(metric.status == .unmeasurable)
        }
    }

    // MARK: - Side View Tests

    @Test("Perfect side posture yields all normal metrics")
    func perfectSidePosture() {
        let results = service.analyzeSideView(joints: perfectSideJoints)

        for metric in results {
            #expect(metric.status == .normal, "Metric \(metric.type) should be normal, got \(metric.status)")
        }
    }

    @Test("Forward head posture detected")
    func forwardHead() {
        var joints = perfectSideJoints
        // Move head forward (positive Z) by 8cm
        if let idx = joints.firstIndex(where: { $0.name == "centerHead" }) {
            joints[idx] = joint("centerHead", x: 0, y: 1.7, z: 0.08)
        }

        let results = service.analyzeSideView(joints: joints)
        let headMetric = results.first { $0.type == .forwardHead }

        #expect(headMetric != nil)
        #expect(headMetric?.status == .caution || headMetric?.status == .warning)
    }

    @Test("Rounded shoulders detected")
    func roundedShoulders() {
        var joints = perfectSideJoints
        // Move shoulders forward (positive Z) by 6cm
        if let idx = joints.firstIndex(where: { $0.name == "centerShoulder" }) {
            joints[idx] = joint("centerShoulder", x: 0, y: 1.4, z: 0.06)
        }

        let results = service.analyzeSideView(joints: joints)
        let shoulderMetric = results.first { $0.type == .roundedShoulders }

        #expect(shoulderMetric != nil)
        #expect(shoulderMetric?.status == .caution || shoulderMetric?.status == .warning)
    }

    @Test("Missing side joints yield unmeasurable results")
    func missingSideJoints() {
        let results = service.analyzeSideView(joints: [])

        for metric in results {
            #expect(metric.status == .unmeasurable)
        }
    }

    // MARK: - Overall Score

    @Test("Overall score for perfect posture is near 100")
    func perfectScore() {
        let frontResults = service.analyzeFrontView(joints: perfectFrontJoints)
        let sideResults = service.analyzeSideView(joints: perfectSideJoints)
        let allMetrics = frontResults + sideResults

        let score = service.calculateOverallScore(metrics: allMetrics)

        #expect(score >= 85, "Perfect posture should score >= 85, got \(score)")
    }

    @Test("Score with all unmeasurable returns 0")
    func allUnmeasurableScore() {
        let frontResults = service.analyzeFrontView(joints: [])
        let sideResults = service.analyzeSideView(joints: [])
        let allMetrics = frontResults + sideResults

        let score = service.calculateOverallScore(metrics: allMetrics)

        #expect(score == 0)
    }

    @Test("Score with empty metrics returns 0")
    func emptyMetricsScore() {
        let score = service.calculateOverallScore(metrics: [])
        #expect(score == 0)
    }

    // MARK: - Edge Cases

    @Test("NaN joint coordinates produce unmeasurable")
    func nanCoordinates() {
        let joints = [
            joint("leftShoulder", x: .nan, y: 1.4, z: 0),
            joint("rightShoulder", x: 0.2, y: .nan, z: 0),
        ]

        let results = service.analyzeFrontView(joints: joints)
        let shoulderMetric = results.first { $0.type == .shoulderAsymmetry }

        #expect(shoulderMetric?.status == .unmeasurable)
    }

    @Test("Infinity joint coordinates produce unmeasurable")
    func infinityCoordinates() {
        let joints = [
            joint("leftShoulder", x: .infinity, y: 1.4, z: 0),
            joint("rightShoulder", x: 0.2, y: 1.4, z: 0),
        ]

        let results = service.analyzeFrontView(joints: joints)
        let shoulderMetric = results.first { $0.type == .shoulderAsymmetry }

        #expect(shoulderMetric?.status == .unmeasurable)
    }
}
