#if !os(visionOS)
import Testing
@testable import DUNE

@Suite("PostureGuidanceAnalyzer Tests")
struct PostureGuidanceAnalyzerTests {

    // MARK: - Distance Status

    @Test("Distance: returns unknown when no keypoints")
    func distanceUnknownWithoutKeypoints() {
        let analyzer = PostureGuidanceAnalyzer()
        let state = analyzer.analyze(observation: nil, keypoints: [], luminance: 0.5)
        #expect(state.distanceStatus == .unknown)
        #expect(!state.isFullBodyVisible)
    }

    @Test("Distance: tooFar when body ratio < 0.4")
    func distanceTooFar() {
        let analyzer = PostureGuidanceAnalyzer()
        // nose at 0.7, ankle at 0.4 → body ratio = 0.3
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.7)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.4)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.4)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.65)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.65)),
            ("leftHip", CGPoint(x: 0.45, y: 0.55)),
            ("rightHip", CGPoint(x: 0.55, y: 0.55)),
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.distanceStatus == .tooFar)
    }

    @Test("Distance: optimal when body ratio 0.55-0.85")
    func distanceOptimal() {
        let analyzer = PostureGuidanceAnalyzer()
        // nose at 0.85, ankle at 0.15 → body ratio = 0.7
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.85)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.15)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.15)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.75)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.75)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.distanceStatus == .optimal)
    }

    @Test("Distance: tooClose when body ratio > 0.85")
    func distanceTooClose() {
        let analyzer = PostureGuidanceAnalyzer()
        // nose at 0.95, ankle at 0.02 → body ratio = 0.93
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.95)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.02)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.02)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.85)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.85)),
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
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.8)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.1)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.1)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
        ]
        // Only 3 frames
        for _ in 0..<3 {
            _ = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        }
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(!state.isStable)
    }

    @Test("Stability: stable after 5 consistent frames")
    func stabilityAfterConsistentFrames() {
        let analyzer = PostureGuidanceAnalyzer()
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.8)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.1)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.1)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
        ]
        // 5+ consistent frames
        for _ in 0..<6 {
            _ = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        }
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.isStable)
    }

    // MARK: - Arms Relaxed

    @Test("Arms: relaxed when wrists below hip level")
    func armsRelaxed() {
        let analyzer = PostureGuidanceAnalyzer()
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.8)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.1)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.1)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
            ("leftWrist", CGPoint(x: 0.35, y: 0.45)),  // Below hip
            ("rightWrist", CGPoint(x: 0.65, y: 0.45)), // Below hip
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(state.areArmsRelaxed)
    }

    @Test("Arms: not relaxed when wrists raised above hips")
    func armsNotRelaxed() {
        let analyzer = PostureGuidanceAnalyzer()
        let keypoints: [(String, CGPoint)] = [
            ("nose", CGPoint(x: 0.5, y: 0.8)),
            ("leftAnkle", CGPoint(x: 0.45, y: 0.1)),
            ("rightAnkle", CGPoint(x: 0.55, y: 0.1)),
            ("leftShoulder", CGPoint(x: 0.4, y: 0.7)),
            ("rightShoulder", CGPoint(x: 0.6, y: 0.7)),
            ("leftHip", CGPoint(x: 0.45, y: 0.5)),
            ("rightHip", CGPoint(x: 0.55, y: 0.5)),
            ("leftWrist", CGPoint(x: 0.35, y: 0.7)),  // Above hip + tolerance
            ("rightWrist", CGPoint(x: 0.65, y: 0.7)), // Above hip + tolerance
        ]
        let state = analyzer.analyze(observation: nil, keypoints: keypoints, luminance: 0.5)
        #expect(!state.areArmsRelaxed)
    }

    // MARK: - Guidance State

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
}
#endif
