#if !os(visionOS)
import Testing
@testable import DUNE

@Suite("PostureGuidanceAnalyzer Tests")
struct PostureGuidanceAnalyzerTests {

    // MARK: - Helper

    private static let standardKeypoints: [(String, CGPoint)] = [
        ("nose", CGPoint(x: 0.5, y: 0.8)),
        ("leftAnkle", CGPoint(x: 0.45, y: 0.1)),
        ("rightAnkle", CGPoint(x: 0.55, y: 0.1)),
        ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
        ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
        ("leftHip", CGPoint(x: 0.45, y: 0.5)),
        ("rightHip", CGPoint(x: 0.55, y: 0.5)),
    ]

    // MARK: - Distance Status

    @Test("Distance: returns unknown when no keypoints")
    func distanceUnknownWithoutKeypoints() {
        let analyzer = PostureGuidanceAnalyzer()
        let state = analyzer.analyze(observation: nil, keypoints: [], luminance: 0.5)
        #expect(state.distanceStatus == .unknown)
        #expect(!state.isFullBodyVisible)
    }

    @Test("Distance: tooFar when body ratio < 0.35")
    func distanceTooFar() {
        let analyzer = PostureGuidanceAnalyzer()
        // nose at 0.6, ankle at 0.35 → body ratio = 0.25
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.6)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.35)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.35)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.55)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.55)),
            ("leftHip", CGPoint(x: 0.45, y: 0.45)),
            ("rightHip", CGPoint(x: 0.55, y: 0.45)),
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.distanceStatus == .tooFar)
    }

    @Test("Distance: optimal when body ratio 0.45-0.90")
    func distanceOptimal() {
        let analyzer = PostureGuidanceAnalyzer()
        // nose at 0.85, ankle at 0.15 → body ratio = 0.7
        let state = analyzer.analyze(
            observation: nil,
            keypoints: Self.standardKeypoints,
            luminance: 0.5
        )
        #expect(state.distanceStatus == .optimal)
    }

    @Test("Distance: tooClose when body ratio > 0.90")
    func distanceTooClose() {
        let analyzer = PostureGuidanceAnalyzer()
        // nose at 0.97, ankle at 0.02 → body ratio = 0.95
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.97)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.02)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.02)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.87)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.87)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.distanceStatus == .tooClose)
    }

    // MARK: - Full Body Detection

    @Test("Full body: visible when nose + ankles detected")
    func fullBodyVisible() {
        let analyzer = PostureGuidanceAnalyzer()
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.8)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.1)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.isFullBodyVisible)
    }

    @Test("Full body: not visible without ankles")
    func fullBodyNotVisibleWithoutAnkles() {
        let analyzer = PostureGuidanceAnalyzer()
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.8)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(!state.isFullBodyVisible)
    }

    // MARK: - Lighting

    @Test("Lighting: tooLow when luminance < 0.15")
    func lightingTooLow() {
        let analyzer = PostureGuidanceAnalyzer()
        let state = analyzer.analyze(observation: nil, keypoints: [], luminance: 0.1)
        #expect(state.lightingStatus == .tooLow)
    }

    @Test("Lighting: adequate when luminance 0.15-0.25")
    func lightingAdequate() {
        let analyzer = PostureGuidanceAnalyzer()
        let state = analyzer.analyze(observation: nil, keypoints: [], luminance: 0.2)
        #expect(state.lightingStatus == .adequate)
    }

    @Test("Lighting: good when luminance > 0.25")
    func lightingGood() {
        let analyzer = PostureGuidanceAnalyzer()
        let state = analyzer.analyze(observation: nil, keypoints: [], luminance: 0.5)
        #expect(state.lightingStatus == .good)
    }

    // MARK: - Stability

    @Test("Stability: not stable with fewer than 5 frames")
    func stabilityNeedsFrames() {
        let analyzer = PostureGuidanceAnalyzer()
        // Only 3 frames — checkStability needs 5
        for _ in 0..<3 {
            _ = analyzer.analyze(
                observation: nil,
                keypoints: Self.standardKeypoints,
                luminance: 0.5
            )
        }
        let state = analyzer.analyze(
            observation: nil,
            keypoints: Self.standardKeypoints,
            luminance: 0.5
        )
        #expect(!state.isStable)
    }

    @Test("Stability: stable after 5 consistent frames")
    func stabilityAfterConsistentFrames() {
        let analyzer = PostureGuidanceAnalyzer()
        // 5+ consistent frames with same nose position
        for _ in 0..<6 {
            _ = analyzer.analyze(
                observation: nil,
                keypoints: Self.standardKeypoints,
                luminance: 0.5
            )
        }
        let state = analyzer.analyze(
            observation: nil,
            keypoints: Self.standardKeypoints,
            luminance: 0.5
        )
        #expect(state.isStable)
    }

    @Test("Stability: unstable when nose moves between frames")
    func stabilityUnstableWithMovement() {
        let analyzer = PostureGuidanceAnalyzer()
        // Feed frames with varying nose positions
        for i in 0..<6 {
            let offset = CGFloat(i) * 0.01
            var kp = Self.standardKeypoints
            kp[0] = ("nose", CGPoint(x: 0.5 + offset, y: 0.8))
            _ = analyzer.analyze(observation: nil, keypoints: kp, luminance: 0.5)
        }
        let state = analyzer.analyze(
            observation: nil,
            keypoints: Self.standardKeypoints,
            luminance: 0.5
        )
        #expect(!state.isStable)
    }

    // MARK: - Arms Relaxed

    @Test("Arms: relaxed when wrists below hip level")
    func armsRelaxed() {
        let analyzer = PostureGuidanceAnalyzer()
        var keypoints = Self.standardKeypoints
        keypoints.append(("leftWrist", CGPoint(x: 0.35, y: 0.45)))  // Below hip
        keypoints.append(("rightWrist", CGPoint(x: 0.65, y: 0.45))) // Below hip
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.areArmsRelaxed)
    }

    @Test("Arms: not relaxed when wrists raised above hips")
    func armsNotRelaxed() {
        let analyzer = PostureGuidanceAnalyzer()
        var keypoints = Self.standardKeypoints
        keypoints.append(("leftWrist", CGPoint(x: 0.35, y: 0.7)))  // Above hip + tolerance
        keypoints.append(("rightWrist", CGPoint(x: 0.65, y: 0.7))) // Above hip + tolerance
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(!state.areArmsRelaxed)
    }

    // MARK: - Guidance State Model

    @Test("GuidanceState: isReady when all conditions met")
    func guidanceStateIsReady() {
        var state = GuidanceState()
        state.isFullBodyVisible = true
        state.distanceStatus = .optimal
        state.isStable = true
        state.lightingStatus = .good
        state.isCorrectOrientation = true
        state.areArmsRelaxed = true
        #expect(state.isReady)
    }

    @Test("GuidanceState: isReady with slightlyFar distance")
    func guidanceStateIsReadySlightlyFar() {
        var state = GuidanceState()
        state.isFullBodyVisible = true
        state.distanceStatus = .slightlyFar
        state.isStable = true
        state.lightingStatus = .good
        state.isCorrectOrientation = true
        state.areArmsRelaxed = true
        #expect(state.isReady)
    }

    @Test("GuidanceState: not ready when any condition fails")
    func guidanceStateNotReady() {
        var state = GuidanceState()
        state.isFullBodyVisible = true
        state.distanceStatus = .optimal
        state.isStable = false  // Not stable
        state.lightingStatus = .good
        state.isCorrectOrientation = true
        state.areArmsRelaxed = true
        #expect(!state.isReady)
    }

    @Test("GuidanceState: primaryHint returns most important unmet condition")
    func guidanceStatePrimaryHint() {
        var state = GuidanceState()
        // Nothing satisfied
        #expect(state.primaryHint == .fullBodyNotVisible)

        state.isFullBodyVisible = true
        state.distanceStatus = .tooClose
        #expect(state.primaryHint == .tooClose)

        state.distanceStatus = .optimal
        state.lightingStatus = .tooLow
        #expect(state.primaryHint == .lowLighting)

        state.lightingStatus = .good
        state.isCorrectOrientation = false
        #expect(state.primaryHint == .wrongOrientation)

        state.isCorrectOrientation = true
        state.areArmsRelaxed = false
        #expect(state.primaryHint == .armsNotRelaxed)

        state.areArmsRelaxed = true
        state.isStable = false
        #expect(state.primaryHint == .notStable)

        state.isStable = true
        #expect(state.primaryHint == nil) // All satisfied
    }

    @Test("GuidanceState: satisfiedCount counts met conditions")
    func guidanceStateSatisfiedCount() {
        var state = GuidanceState()
        #expect(state.satisfiedCount == 0)

        state.isFullBodyVisible = true
        #expect(state.satisfiedCount == 1)

        state.distanceStatus = .optimal
        #expect(state.satisfiedCount == 2)

        state.isStable = true
        state.lightingStatus = .good
        #expect(state.satisfiedCount == 4)
    }

    @Test("GuidanceState: isDistanceAcceptable for optimal and slightlyFar")
    func guidanceStateDistanceAcceptable() {
        var state = GuidanceState()
        #expect(!state.isDistanceAcceptable) // unknown

        state.distanceStatus = .optimal
        #expect(state.isDistanceAcceptable)

        state.distanceStatus = .slightlyFar
        #expect(state.isDistanceAcceptable)

        state.distanceStatus = .tooFar
        #expect(!state.isDistanceAcceptable)

        state.distanceStatus = .tooClose
        #expect(!state.isDistanceAcceptable)
    }
}
#endif
