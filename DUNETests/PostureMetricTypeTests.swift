import Foundation
import Testing

@testable import DUNE

@Suite("PostureMetricType")
struct PostureMetricTypeTests {

    @Test("Every metric type has non-empty affectedJointNames")
    func allMetricsHaveJoints() {
        for metricType in PostureMetricType.allCases {
            #expect(
                !metricType.affectedJointNames.isEmpty,
                "\(metricType.rawValue) should have at least one affected joint"
            )
        }
    }

    @Test("affectedJointNames for forwardHead includes head and shoulder")
    func forwardHeadJoints() {
        let joints = PostureMetricType.forwardHead.affectedJointNames
        #expect(joints.contains("centerHead"))
        #expect(joints.contains("centerShoulder"))
    }

    @Test("affectedJointNames for shoulderAsymmetry includes both shoulders")
    func shoulderAsymmetryJoints() {
        let joints = PostureMetricType.shoulderAsymmetry.affectedJointNames
        #expect(joints.contains("leftShoulder"))
        #expect(joints.contains("rightShoulder"))
    }

    @Test("affectedJointNames for hipAsymmetry includes both hips")
    func hipAsymmetryJoints() {
        let joints = PostureMetricType.hipAsymmetry.affectedJointNames
        #expect(joints.contains("leftHip"))
        #expect(joints.contains("rightHip"))
    }

    @Test("affectedJointNames for kneeAlignment includes both knees")
    func kneeAlignmentJoints() {
        let joints = PostureMetricType.kneeAlignment.affectedJointNames
        #expect(joints.contains("leftKnee"))
        #expect(joints.contains("rightKnee"))
    }

    @Test("Side view metrics reference appropriate joints")
    func sideViewMetricJoints() {
        // thoracicKyphosis should affect upper back joints
        let kyphosis = PostureMetricType.thoracicKyphosis.affectedJointNames
        #expect(kyphosis.contains("centerShoulder"))
        #expect(kyphosis.contains("spine"))

        // kneeHyperextension should affect knee/ankle joints
        let hyperext = PostureMetricType.kneeHyperextension.affectedJointNames
        #expect(hyperext.contains("leftKnee"))
        #expect(hyperext.contains("rightAnkle"))
    }

    // MARK: - AffectedBodyParts (Injury Integration)

    @Test("Every metric type has non-empty affectedBodyParts")
    func allMetricsHaveBodyParts() {
        for metricType in PostureMetricType.allCases {
            #expect(
                !metricType.affectedBodyParts.isEmpty,
                "\(metricType.rawValue) should map to at least one body part"
            )
        }
    }

    @Test("forwardHead maps to neck")
    func forwardHeadBodyParts() {
        #expect(PostureMetricType.forwardHead.affectedBodyParts == [.neck])
    }

    @Test("shoulderAsymmetry maps to shoulder")
    func shoulderAsymmetryBodyParts() {
        #expect(PostureMetricType.shoulderAsymmetry.affectedBodyParts == [.shoulder])
    }

    @Test("hipAsymmetry maps to hip")
    func hipAsymmetryBodyParts() {
        #expect(PostureMetricType.hipAsymmetry.affectedBodyParts == [.hip])
    }

    @Test("kneeAlignment maps to knee")
    func kneeAlignmentBodyParts() {
        #expect(PostureMetricType.kneeAlignment.affectedBodyParts == [.knee])
    }

    @Test("thoracicKyphosis maps to lowerBack")
    func thoracicKyphosisBodyParts() {
        #expect(PostureMetricType.thoracicKyphosis.affectedBodyParts == [.lowerBack])
    }

    // MARK: - PostureMetricResult Confidence

    @Test("PostureMetricResult decodes without confidence field (backward compatibility)")
    func decodeWithoutConfidence() throws {
        let json = """
        {"type":"forwardHead","value":12.5,"unit":"degrees","status":"caution","score":70}
        """
        let data = Data(json.utf8)
        let result = try JSONDecoder().decode(PostureMetricResult.self, from: data)
        #expect(result.confidence == 1.0)
        #expect(result.type == .forwardHead)
        #expect(result.value == 12.5)
        #expect(result.score == 70)
    }

    @Test("PostureMetricResult decodes with confidence field")
    func decodeWithConfidence() throws {
        let json = """
        {"type":"roundedShoulders","value":8.3,"unit":"degrees","status":"normal","score":90,"confidence":0.85}
        """
        let data = Data(json.utf8)
        let result = try JSONDecoder().decode(PostureMetricResult.self, from: data)
        #expect(result.confidence == 0.85)
        #expect(result.type == .roundedShoulders)
    }

    @Test("PostureMetricResult confidence is clamped to 0-1")
    func confidenceClamped() {
        let overOne = PostureMetricResult(
            type: .forwardHead, value: 10, unit: .degrees,
            status: .normal, score: 80, confidence: 1.5
        )
        #expect(overOne.confidence == 1.0)

        let underZero = PostureMetricResult(
            type: .forwardHead, value: 10, unit: .degrees,
            status: .normal, score: 80, confidence: -0.5
        )
        #expect(underZero.confidence == 0.0)
    }

    @Test("PostureMetricResult roundtrip encoding preserves confidence")
    func roundtripConfidence() throws {
        let original = PostureMetricResult(
            type: .hipAsymmetry, value: 2.1, unit: .centimeters,
            status: .caution, score: 65, confidence: 0.72
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PostureMetricResult.self, from: data)
        #expect(decoded.confidence == 0.72)
        #expect(decoded.type == original.type)
        #expect(decoded.value == original.value)
    }
}
