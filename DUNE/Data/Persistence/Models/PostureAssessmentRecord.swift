import Foundation
import SwiftData

@Model
final class PostureAssessmentRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var overallScore: Int = 0
    var frontMetricsJSON: String = "[]"
    var sideMetricsJSON: String = "[]"
    var frontJointPositionsJSON: String = "[]"
    var sideJointPositionsJSON: String = "[]"
    var frontImageData: Data?
    var sideImageData: Data?
    var bodyHeight: Double?
    var heightEstimationRaw: String = HeightEstimationType.reference.rawValue
    var memo: String = ""
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        overallScore: Int = 0,
        frontMetrics: [PostureMetricResult] = [],
        sideMetrics: [PostureMetricResult] = [],
        frontJointPositions: [JointPosition3D] = [],
        sideJointPositions: [JointPosition3D] = [],
        frontImageData: Data? = nil,
        sideImageData: Data? = nil,
        bodyHeight: Double? = nil,
        heightEstimation: HeightEstimationType = .reference,
        memo: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.overallScore = max(0, min(100, overallScore))
        self.frontMetricsJSON = Self.encode(frontMetrics)
        self.sideMetricsJSON = Self.encode(sideMetrics)
        self.frontJointPositionsJSON = Self.encode(frontJointPositions)
        self.sideJointPositionsJSON = Self.encode(sideJointPositions)
        self.frontImageData = frontImageData
        self.sideImageData = sideImageData
        self.bodyHeight = bodyHeight
        self.heightEstimationRaw = heightEstimation.rawValue
        self.memo = memo
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    var heightEstimation: HeightEstimationType {
        HeightEstimationType(rawValue: heightEstimationRaw) ?? .reference
    }

    var frontMetrics: [PostureMetricResult] {
        Self.decode(frontMetricsJSON)
    }

    var sideMetrics: [PostureMetricResult] {
        Self.decode(sideMetricsJSON)
    }

    var allMetrics: [PostureMetricResult] {
        frontMetrics + sideMetrics
    }

    var frontJointPositions: [JointPosition3D] {
        Self.decode(frontJointPositionsJSON)
    }

    var sideJointPositions: [JointPosition3D] {
        Self.decode(sideJointPositionsJSON)
    }

    // MARK: - JSON Helpers

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder = JSONDecoder()

    private static func encode<T: Encodable>(_ value: T) -> String {
        (try? String(data: encoder.encode(value), encoding: .utf8)) ?? "[]"
    }

    private static func decode<T: Decodable>(_ json: String) -> [T] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? decoder.decode([T].self, from: data)) ?? []
    }
}
