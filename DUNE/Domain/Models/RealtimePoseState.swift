import Foundation

// MARK: - Realtime Angle

/// A single joint angle measurement from realtime pose analysis.
struct RealtimeAngle: Sendable, Hashable, Identifiable {
    var id: AngleType { type }

    let type: AngleType
    let degrees: Double
    let status: PostureStatus
    /// Normalized screen position (0-1) where the angle should be displayed.
    let displayPosition: CGPoint

    enum AngleType: String, Sendable, Hashable, CaseIterable {
        case leftKnee
        case rightKnee
        case shoulderTilt     // Left-right shoulder height difference proxy
        case trunkLean        // Lateral trunk shift proxy
        case hipAngle         // Hip flexion (side view)
    }
}

// MARK: - Realtime Pose Snapshot

/// A single frame's pose data with estimated angles.
struct RealtimePoseSnapshot: Sendable {
    let timestamp: CFAbsoluteTime
    let keypoints2D: [(String, CGPoint)]
    let angles: [RealtimeAngle]
    /// 3D analysis result (populated only on 3D sample frames).
    let analysis3D: [PostureMetricResult]?
}

// MARK: - Realtime Pose State

/// Observable state for the realtime posture analysis mode.
struct RealtimePoseState: Sendable {
    var isActive: Bool = false
    var currentAngles: [RealtimeAngle] = []
    var currentScore: Int = 0
    var smoothedScore: Int = 0
    var skeletonKeypoints: [(String, CGPoint)] = []
    var guidanceState = GuidanceState()
    /// Latest 3D analysis metrics (updated at 3D sample rate).
    var latestMetrics: [PostureMetricResult] = []
    /// Whether 3D pipeline is producing results.
    var is3DActive: Bool = false
    /// Frames since last valid detection (for timeout).
    var framesSinceLastDetection: Int = 0

    static let detectionTimeoutFrames = 9 // ~300ms at 30fps
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
