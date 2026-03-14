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
}
