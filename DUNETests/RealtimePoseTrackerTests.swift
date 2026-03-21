import Foundation
import Testing

@testable import DUNE

@Suite("RealtimePoseTracker")
struct RealtimePoseTrackerTests {

    @Test("Precise 3D score is unavailable for 2D fallback results")
    func preciseScoreUnavailableForFallback() {
        let result = PostureCaptureResult(
            jointPositions: [JointPosition3D(name: "root", x: 0, y: 0, z: 0)],
            bodyHeight: 1.8,
            heightEstimation: .reference,
            imageData: nil,
            poseSource: .twoDFallback
        )

        #expect(RealtimePoseTracker.preciseScoreIfAvailable(from: result) == nil)
    }

    @Test("Precise 3D score is computed for true 3D results")
    func preciseScoreAvailableForTrue3D() {
        let result = PostureCaptureResult(
            jointPositions: [JointPosition3D(name: "root", x: 0, y: 0, z: 0)],
            bodyHeight: 1.8,
            heightEstimation: .reference,
            imageData: nil,
            poseSource: .threeD
        )

        #expect(RealtimePoseTracker.preciseScoreIfAvailable(from: result) != nil)
    }
}
