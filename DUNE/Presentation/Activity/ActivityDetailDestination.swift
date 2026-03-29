import Foundation

/// Navigation destinations for Activity tab detail views.
enum ActivityDetailDestination: Hashable {
    case muscleMap
    case muscleMap3D
    case personalRecords(preselectedKind: ActivityPersonalRecord.Kind? = nil)
    case consistency
    case exerciseMix
    case trainingReadiness
    case weeklyStats
    case injuryRisk
    case weeklyReport
}
