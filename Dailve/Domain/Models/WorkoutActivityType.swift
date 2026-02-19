import Foundation

// MARK: - WorkoutActivityType

/// Domain-level workout activity type matching HKWorkoutActivityType cases.
/// HealthKit import is forbidden in Domain — the Data layer maps between this and HKWorkoutActivityType.
enum WorkoutActivityType: String, Codable, Sendable, CaseIterable {
    // Cardio
    case running
    case walking
    case cycling
    case swimming
    case hiking
    case elliptical
    case rowing
    case stairClimbing
    case stairStepper
    case jumpRope
    case stepTraining
    case handCycling

    // Strength
    case traditionalStrengthTraining
    case functionalStrengthTraining
    case coreTraining

    // HIIT / Cross
    case highIntensityIntervalTraining
    case mixedCardio
    case crossTraining

    // Mind & Body
    case yoga
    case pilates
    case flexibility
    case taiChi
    case mindAndBody
    case barre
    case cooldown
    case preparationAndRecovery

    // Dance
    case socialDance
    case cardioDance

    // Combat
    case boxing
    case martialArts
    case wrestling
    case kickboxing
    case fencing

    // Team Sports
    case basketball
    case soccer
    case tennis
    case badminton
    case tableTennis
    case volleyball
    case baseball
    case softball
    case americanFootball
    case rugby
    case hockey
    case lacrosse
    case cricket
    case handball
    case racquetball
    case squash
    case pickleball
    case bowling
    case golf
    case discSports
    case australianFootball

    // Water
    case paddleSports
    case surfingSports
    case waterFitness
    case waterPolo
    case waterSports
    case sailing

    // Winter
    case downhillSkiing
    case snowboarding
    case crossCountrySkiing
    case snowSports
    case skating

    // Outdoor
    case climbing
    case mountaineering
    case equestrianSports
    case fishing
    case hunting
    case archery
    case trackAndField
    case curling

    // Multi-sport
    case swimBikeRun
    case transition

    // Other
    case fitnessGaming
    case play
    case underwaterDiving
    case wheelchairRunPace
    case wheelchairWalkPace
    case other

    // MARK: - Muscle Mapping

    /// Primary muscle groups engaged by this activity type.
    /// Used to include HealthKit workouts in muscle recovery tracking.
    var primaryMuscles: [MuscleGroup] {
        switch self {
        case .running, .walking, .hiking, .stairClimbing, .stairStepper, .stepTraining:
            return [.quadriceps, .hamstrings, .glutes, .calves]
        case .cycling, .handCycling:
            return [.quadriceps, .hamstrings, .glutes]
        case .swimming:
            return [.lats, .shoulders, .core]
        case .elliptical:
            return [.quadriceps, .hamstrings, .glutes]
        case .rowing:
            return [.back, .lats, .biceps]
        case .jumpRope:
            return [.calves, .quadriceps, .shoulders]
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return [] // Too broad — actual muscles come from ExerciseRecord
        case .coreTraining:
            return [.core]
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio:
            return [.quadriceps, .core]
        case .yoga, .pilates, .barre:
            return [.core, .glutes]
        case .boxing, .kickboxing:
            return [.shoulders, .core, .biceps]
        case .martialArts, .wrestling:
            return [.core, .shoulders]
        case .climbing, .mountaineering:
            return [.forearms, .lats, .biceps]
        case .basketball, .soccer, .volleyball, .rugby, .americanFootball:
            return [.quadriceps, .hamstrings, .calves]
        case .tennis, .badminton, .tableTennis, .racquetball, .squash, .pickleball:
            return [.shoulders, .forearms, .quadriceps]
        case .downhillSkiing, .crossCountrySkiing, .snowboarding, .snowSports, .skating:
            return [.quadriceps, .glutes, .core]
        case .surfingSports, .paddleSports:
            return [.shoulders, .lats, .core]
        default:
            return []
        }
    }

    /// Secondary muscle groups engaged by this activity type.
    var secondaryMuscles: [MuscleGroup] {
        switch self {
        case .running, .walking, .hiking:
            return [.core]
        case .cycling:
            return [.calves, .core]
        case .swimming:
            return [.triceps, .chest]
        case .rowing:
            return [.core, .hamstrings, .shoulders]
        case .boxing, .kickboxing:
            return [.triceps, .forearms]
        case .climbing, .mountaineering:
            return [.shoulders, .core]
        default:
            return []
        }
    }

    // MARK: - Computed Properties

    /// Whether this activity primarily measures distance.
    var isDistanceBased: Bool {
        switch self {
        case .running, .walking, .cycling, .swimming, .hiking,
             .elliptical, .rowing, .handCycling, .crossCountrySkiing,
             .downhillSkiing, .paddleSports, .swimBikeRun:
            return true
        default:
            return false
        }
    }

    /// High-level category for grouping and coloring.
    var category: ActivityCategory {
        switch self {
        case .running, .walking, .cycling, .hiking, .elliptical, .rowing,
             .stairClimbing, .stairStepper, .jumpRope, .stepTraining, .handCycling,
             .mixedCardio, .crossTraining, .highIntensityIntervalTraining:
            return .cardio
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .strength
        case .yoga, .pilates, .flexibility, .taiChi, .mindAndBody, .barre,
             .cooldown, .preparationAndRecovery:
            return .mindBody
        case .socialDance, .cardioDance:
            return .dance
        case .boxing, .martialArts, .wrestling, .kickboxing, .fencing:
            return .combat
        case .basketball, .soccer, .tennis, .badminton, .tableTennis,
             .volleyball, .baseball, .softball, .americanFootball,
             .rugby, .hockey, .lacrosse, .cricket, .handball,
             .racquetball, .squash, .pickleball, .bowling, .golf,
             .discSports, .australianFootball, .trackAndField, .curling:
            return .sports
        case .swimming, .paddleSports, .surfingSports, .waterFitness,
             .waterPolo, .waterSports, .sailing, .underwaterDiving:
            return .water
        case .downhillSkiing, .snowboarding, .crossCountrySkiing,
             .snowSports, .skating:
            return .winter
        case .climbing, .mountaineering, .equestrianSports, .fishing,
             .hunting, .archery:
            return .outdoor
        case .swimBikeRun, .transition:
            return .multiSport
        case .fitnessGaming, .play, .wheelchairRunPace, .wheelchairWalkPace, .other:
            return .other
        }
    }

    /// The English type name used for backward compatibility with existing `WorkoutSummary.type`.
    var typeName: String {
        switch self {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength"
        case .highIntensityIntervalTraining: "HIIT"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .coreTraining: "Core"
        case .flexibility: "Flexibility"
        case .socialDance, .cardioDance: "Dance"
        case .pilates: "Pilates"
        case .boxing: "Boxing"
        case .martialArts: "Martial Arts"
        case .climbing: "Climbing"
        case .basketball: "Basketball"
        case .soccer: "Soccer"
        case .tennis: "Tennis"
        case .golf: "Golf"
        case .jumpRope: "Jump Rope"
        case .stairClimbing: "Stair Climbing"
        case .stairStepper: "Stair Stepper"
        case .crossTraining: "Cross Training"
        case .mixedCardio: "Mixed Cardio"
        case .kickboxing: "Kickboxing"
        case .snowboarding: "Snowboarding"
        case .downhillSkiing: "Skiing"
        case .crossCountrySkiing: "Cross-Country Skiing"
        case .surfingSports: "Surfing"
        case .paddleSports: "Paddle Sports"
        case .mountaineering: "Mountaineering"
        case .badminton: "Badminton"
        case .tableTennis: "Table Tennis"
        case .volleyball: "Volleyball"
        case .baseball: "Baseball"
        case .softball: "Softball"
        case .americanFootball: "American Football"
        case .rugby: "Rugby"
        case .hockey: "Hockey"
        case .lacrosse: "Lacrosse"
        case .cricket: "Cricket"
        case .handball: "Handball"
        case .racquetball: "Racquetball"
        case .squash: "Squash"
        case .pickleball: "Pickleball"
        case .bowling: "Bowling"
        case .discSports: "Disc Sports"
        case .australianFootball: "Australian Football"
        case .waterFitness: "Water Fitness"
        case .waterPolo: "Water Polo"
        case .waterSports: "Water Sports"
        case .sailing: "Sailing"
        case .snowSports: "Snow Sports"
        case .skating: "Skating"
        case .equestrianSports: "Equestrian"
        case .fishing: "Fishing"
        case .hunting: "Hunting"
        case .archery: "Archery"
        case .trackAndField: "Track & Field"
        case .curling: "Curling"
        case .fencing: "Fencing"
        case .wrestling: "Wrestling"
        case .taiChi: "Tai Chi"
        case .mindAndBody: "Mind & Body"
        case .barre: "Barre"
        case .cooldown: "Cooldown"
        case .preparationAndRecovery: "Recovery"
        case .swimBikeRun: "Triathlon"
        case .transition: "Transition"
        case .fitnessGaming: "Fitness Gaming"
        case .play: "Play"
        case .underwaterDiving: "Diving"
        case .handCycling: "Hand Cycling"
        case .wheelchairRunPace: "Wheelchair Run"
        case .wheelchairWalkPace: "Wheelchair Walk"
        case .stepTraining: "Step Training"
        case .other: "Workout"
        }
    }

    // MARK: - Name-Based Inference

    /// Infers a `WorkoutActivityType` from an exercise name string.
    /// Returns `nil` if no keyword matches, allowing the caller to apply a category-based fallback.
    static func infer(from exerciseName: String) -> WorkoutActivityType? {
        let name = exerciseName.lowercased()
        switch name {
        case let n where n.contains("running") || n.contains("run"):   return .running
        case let n where n.contains("walking") || n.contains("walk"):  return .walking
        case let n where n.contains("cycling") || n.contains("bike") || n.contains("cycle"):  return .cycling
        case let n where n.contains("swimming") || n.contains("swim"): return .swimming
        case let n where n.contains("hiking") || n.contains("hike"):   return .hiking
        case let n where n.contains("yoga"):       return .yoga
        case let n where n.contains("pilates"):    return .pilates
        case let n where n.contains("rowing") || n.contains("row"):    return .rowing
        case let n where n.contains("elliptical"): return .elliptical
        case let n where n.contains("dance") || n.contains("dancing"): return .socialDance
        case let n where n.contains("core"):       return .coreTraining
        case let n where n.contains("boxing"):     return .boxing
        case let n where n.contains("kickbox"):    return .kickboxing
        case let n where n.contains("climb"):      return .climbing
        case let n where n.contains("jump rope") || n.contains("jumprope"): return .jumpRope
        default: return nil
        }
    }
}

// MARK: - ActivityCategory

/// High-level grouping for workout activity types.
enum ActivityCategory: String, Codable, Sendable {
    case cardio
    case strength
    case mindBody
    case dance
    case combat
    case sports
    case water
    case winter
    case outdoor
    case multiSport
    case other
}

// MARK: - MilestoneDistance

/// Standard distance milestones for running/cycling achievements.
enum MilestoneDistance: String, Codable, Sendable, CaseIterable {
    case fiveK
    case tenK
    case halfMarathon
    case marathon

    /// Distance in meters.
    var meters: Double {
        switch self {
        case .fiveK: 5_000
        case .tenK: 10_000
        case .halfMarathon: 21_097
        case .marathon: 42_195
        }
    }

    /// Display label.
    var label: String {
        switch self {
        case .fiveK: "5K"
        case .tenK: "10K"
        case .halfMarathon: "Half"
        case .marathon: "Marathon"
        }
    }

    /// Detects the highest milestone achieved for a given distance in meters.
    static func detect(from distanceMeters: Double?) -> MilestoneDistance? {
        guard let distance = distanceMeters, distance > 0, distance.isFinite else { return nil }
        // Check from highest to lowest
        for milestone in [MilestoneDistance.marathon, .halfMarathon, .tenK, .fiveK] {
            if distance >= milestone.meters {
                return milestone
            }
        }
        return nil
    }
}

// MARK: - PersonalRecordType

/// Types of personal records that can be tracked.
enum PersonalRecordType: String, Codable, Sendable {
    case fastestPace       // Best avg pace for a milestone distance
    case longestDistance    // Longest total distance
    case highestCalories   // Most calories burned in a session
    case longestDuration   // Longest workout duration
    case highestElevation  // Most elevation gained
}
