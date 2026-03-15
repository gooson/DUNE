import Foundation
import Observation

@Observable
@MainActor
final class PostureSymmetryViewModel {

    // MARK: - State

    private(set) var symmetryDetails: [SymmetryDetail] = []
    private(set) var hasData = false

    private let analysisService = PostureAnalysisService()

    // MARK: - Load

    func loadSymmetry(from record: PostureAssessmentRecord) {
        let frontJoints = record.frontJointPositions
        guard !frontJoints.isEmpty else {
            symmetryDetails = []
            hasData = false
            return
        }

        symmetryDetails = analysisService.analyzeSymmetryDetails(joints: frontJoints)
        hasData = !symmetryDetails.isEmpty
    }
}
