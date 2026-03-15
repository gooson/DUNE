import Foundation
import Testing
import Vision

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
    func shoulderAsymmetry() throws {
        var joints = perfectFrontJoints
        // Make left shoulder 4cm higher
        if let idx = joints.firstIndex(where: { $0.name == "leftShoulder" }) {
            joints[idx] = joint("leftShoulder", x: -0.2, y: 1.44, z: 0)
        }

        let results = service.analyzeFrontView(joints: joints)
        let shoulderMetric = try #require(results.first { $0.type == .shoulderAsymmetry })

        #expect(shoulderMetric.status == .caution || shoulderMetric.status == .warning)
        #expect(shoulderMetric.value > 3.0, "Expected > 3cm asymmetry")
    }

    @Test("Hip asymmetry detected with uneven hips")
    func hipAsymmetry() throws {
        var joints = perfectFrontJoints
        if let idx = joints.firstIndex(where: { $0.name == "leftHip" }) {
            joints[idx] = joint("leftHip", x: -0.12, y: 0.94, z: 0)
        }

        let results = service.analyzeFrontView(joints: joints)
        let hipMetric = try #require(results.first { $0.type == .hipAsymmetry })

        #expect(hipMetric.value > 3.0)
    }

    @Test("Lateral shift detected when head is off-center")
    func lateralShift() throws {
        var joints = perfectFrontJoints
        if let idx = joints.firstIndex(where: { $0.name == "centerHead" }) {
            joints[idx] = joint("centerHead", x: 0.05, y: 1.7, z: 0)
        }

        let results = service.analyzeFrontView(joints: joints)
        let shiftMetric = try #require(results.first { $0.type == .lateralShift })

        #expect(shiftMetric.value > 3.0)
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

    // MARK: - 2D Angle Estimation

    @Test("Perfect standing 2D keypoints yield normal knee angles")
    func perfectStanding2DKnees() {
        // Straight standing posture (normalized Vision coords, origin bottom-left)
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.95)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.8)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.8)),
            ("leftHip", CGPoint(x: 0.42, y: 0.55)),
            ("rightHip", CGPoint(x: 0.58, y: 0.55)),
            ("leftKnee", CGPoint(x: 0.42, y: 0.3)),
            ("rightKnee", CGPoint(x: 0.58, y: 0.3)),
            ("leftAnkle", CGPoint(x: 0.42, y: 0.05)),
            ("rightAnkle", CGPoint(x: 0.58, y: 0.05)),
        ]

        let angles = service.estimateAnglesFrom2D(keypoints: keypoints)
        let leftKnee = angles.first { $0.type == .leftKnee }
        let rightKnee = angles.first { $0.type == .rightKnee }

        #expect(leftKnee?.status == .normal, "Straight knee should be normal")
        #expect(rightKnee?.status == .normal, "Straight knee should be normal")
        #expect((leftKnee?.degrees ?? 0) > 165, "Straight knee angle should be > 165°")
    }

    @Test("Bent knees yield caution or warning")
    func bent2DKnees() {
        // Knees significantly bent (squat-like)
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.85)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.75)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.75)),
            ("leftHip", CGPoint(x: 0.42, y: 0.55)),
            ("rightHip", CGPoint(x: 0.58, y: 0.55)),
            ("leftKnee", CGPoint(x: 0.35, y: 0.35)),   // Knee pushed forward
            ("rightKnee", CGPoint(x: 0.65, y: 0.35)),
            ("leftAnkle", CGPoint(x: 0.42, y: 0.05)),
            ("rightAnkle", CGPoint(x: 0.58, y: 0.05)),
        ]

        let angles = service.estimateAnglesFrom2D(keypoints: keypoints)
        let leftKnee = angles.first { $0.type == .leftKnee }

        #expect(leftKnee != nil)
        #expect(leftKnee?.status == .caution || leftKnee?.status == .warning)
    }

    @Test("Shoulder tilt detected in 2D")
    func shoulderTilt2D() {
        let keypoints: [(String, CGPoint)] = [
            ("leftShoulder", CGPoint(x: 0.4, y: 0.82)),   // Higher
            ("rightShoulder", CGPoint(x: 0.6, y: 0.75)),   // Lower — 0.07 diff
        ]

        let angles = service.estimateAnglesFrom2D(keypoints: keypoints)
        let tilt = angles.first { $0.type == .shoulderTilt }

        #expect(tilt != nil)
        #expect(tilt?.status == .caution || tilt?.status == .warning)
    }

    @Test("Empty 2D keypoints produce no angles")
    func empty2DKeypoints() {
        let angles = service.estimateAnglesFrom2D(keypoints: [])
        #expect(angles.isEmpty)
    }

    // MARK: - ScoreRingBuffer

    @Test("Score ring buffer averages correctly")
    func scoreRingBufferAverage() {
        var buffer = ScoreRingBuffer(capacity: 5)
        buffer.append(80)
        buffer.append(90)
        buffer.append(85)

        #expect(buffer.average == 85) // (80+90+85)/3 = 85

        buffer.append(70)
        buffer.append(75)
        #expect(buffer.average == 80) // (80+90+85+70+75)/5 = 80

        // Overflow capacity — oldest replaced
        buffer.append(100)
        #expect(buffer.average == 84) // (100+90+85+70+75)/5 = 84
    }

    @Test("Score ring buffer replaceLast overwrites most recent")
    func scoreRingBufferReplaceLast() {
        var buffer = ScoreRingBuffer(capacity: 5)
        buffer.append(80)
        buffer.append(90)
        buffer.replaceLast(100) // Replace 90 with 100
        #expect(buffer.average == 90) // (80+100)/2 = 90
    }

    @Test("Score ring buffer reset clears values")
    func scoreRingBufferReset() {
        var buffer = ScoreRingBuffer(capacity: 5)
        buffer.append(80)
        buffer.append(90)
        buffer.reset()

        #expect(buffer.average == 0)
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
            joint("leftShoulder", x: -0.2, y: .infinity, z: 0),
            joint("rightShoulder", x: 0.2, y: 1.4, z: 0),
        ]

        let results = service.analyzeFrontView(joints: joints)
        let shoulderMetric = results.first { $0.type == .shoulderAsymmetry }

        #expect(shoulderMetric?.status == .unmeasurable)
    }
}

@Suite("PostureCaptureService joint filtering")
struct PostureCaptureServiceJointFilteringTests {

    @Test("Reliable captured joints are preserved")
    func keepsReliableJoint() {
        let keep = PostureCaptureService.shouldKeepCapturedJoint(
            confidence: PostureCaptureService.capturedJointMinimumConfidence,
            x: 0,
            y: 1.2,
            z: 0
        )

        #expect(keep)
    }

    @Test("Low-confidence captured joints are dropped")
    func dropsLowConfidenceJoint() {
        let keep = PostureCaptureService.shouldKeepCapturedJoint(
            confidence: PostureCaptureService.capturedJointMinimumConfidence - 0.01,
            x: 0,
            y: 1.2,
            z: 0
        )

        #expect(!keep)
    }

    @Test("Missing mapped 2D confidence drops captured joint")
    func dropsJointWhenMappedConfidenceMissing() {
        let confidence = PostureCaptureService.capturedJointConfidence(
            for: "centerHead",
            confidenceBy2DJointName: [:]
        )
        let keep = PostureCaptureService.shouldKeepCapturedJoint(
            confidence: confidence,
            x: 0,
            y: 1.2,
            z: 0
        )

        #expect(confidence == nil)
        #expect(!keep)
    }

    @Test("Derived captured joints reuse mapped 2D confidences")
    func mapsDerivedJointConfidence() {
        let confidenceBy2DJointName = [
            VNHumanBodyPoseObservation.JointName.nose: Float(0.81),
            VNHumanBodyPoseObservation.JointName.neck: Float(0.72),
            VNHumanBodyPoseObservation.JointName.root: Float(0.64),
            VNHumanBodyPoseObservation.JointName.leftShoulder: Float(0.93),
        ]

        #expect(
            PostureCaptureService.capturedJointConfidence(
                for: "centerHead",
                confidenceBy2DJointName: confidenceBy2DJointName
            ) == 0.81
        )
        #expect(
            PostureCaptureService.capturedJointConfidence(
                for: "centerShoulder",
                confidenceBy2DJointName: confidenceBy2DJointName
            ) == 0.72
        )
        #expect(
            PostureCaptureService.capturedJointConfidence(
                for: "spine",
                confidenceBy2DJointName: confidenceBy2DJointName
            ) == 0.64
        )
        #expect(
            PostureCaptureService.capturedJointConfidence(
                for: "leftShoulder",
                confidenceBy2DJointName: confidenceBy2DJointName
            ) == 0.93
        )
    }

    @Test("Non-finite captured joints are dropped")
    func dropsNonFiniteJoint() {
        #expect(!PostureCaptureService.shouldKeepCapturedJoint(
            confidence: 1.0,
            x: .nan,
            y: 1.2,
            z: 0
        ))
        #expect(!PostureCaptureService.shouldKeepCapturedJoint(
            confidence: 1.0,
            x: 0,
            y: .infinity,
            z: 0
        ))
        #expect(!PostureCaptureService.shouldKeepCapturedJoint(
            confidence: 1.0,
            x: 0,
            y: 1.2,
            z: -.infinity
        ))
    }
}
