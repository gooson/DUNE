import Foundation

// MARK: - Realtime Angle

/// A single joint angle measurement from realtime pose analysis.
struct RealtimeAngle: Sendable, Hashable, Identifiable {
    var id: AngleType { type }

    let type: AngleType
    let degrees: Double
    let status: PostureStatus
    /// Joint name used for position lookup in skeleton keypoints.
    let jointName: String

    enum AngleType: String, Sendable, Hashable, CaseIterable {
        case leftKnee
        case rightKnee
        case shoulderTilt     // Left-right shoulder height difference proxy
        case trunkLean        // Lateral trunk shift proxy
    }
}

// MARK: - Realtime Pose State

/// Observable state for the realtime posture analysis mode.
struct RealtimePoseState: Sendable {
    var isActive: Bool = false
    var currentAngles: [RealtimeAngle] = []
    var smoothedScore: Int = 0
    var skeletonKeypoints: [(String, CGPoint)] = []
    /// Whether 3D pipeline is producing results.
    var is3DActive: Bool = false
    /// Frames since last valid detection (for timeout).
    var framesSinceLastDetection: Int = 0
    /// Exercise form state when form check mode is active.
    var formState: ExerciseFormState?
}

// MARK: - Score Smoothing

/// Ring buffer for score smoothing via moving average.
struct ScoreRingBuffer: Sendable {
    private var buffer: [Int]
    private var index: Int = 0
    private var count: Int = 0
    let capacity: Int

    init(capacity: Int = 10) {
        self.capacity = capacity
        self.buffer = Array(repeating: 0, count: capacity)
    }

    mutating func append(_ value: Int) {
        buffer[index] = value
        index = (index + 1) % capacity
        count = min(count + 1, capacity)
    }

    /// Replace the most recent entry (for 3D score override on same frame).
    mutating func replaceLast(_ value: Int) {
        guard count > 0 else {
            append(value)
            return
        }
        let lastIndex = (index - 1 + capacity) % capacity
        buffer[lastIndex] = value
    }

    var average: Int {
        guard count > 0 else { return 0 }
        let sum = buffer.prefix(count).reduce(0, +)
        return sum / count
    }

    mutating func reset() {
        buffer = Array(repeating: 0, count: capacity)
        index = 0
        count = 0
    }
}
