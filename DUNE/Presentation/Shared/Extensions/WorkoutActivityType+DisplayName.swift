import Foundation

extension WorkoutActivityType {

    /// Localized display name for the activity type.
    var displayName: String {
        switch self {
        case .running: String(localized: "Running")
        case .walking: String(localized: "Walking")
        case .cycling: String(localized: "Cycling")
        case .swimming: String(localized: "Swimming")
        case .hiking: String(localized: "Hiking")
        case .yoga: String(localized: "Yoga")
        case .traditionalStrengthTraining: String(localized: "Weight Training")
        case .functionalStrengthTraining: String(localized: "Functional Strength")
        case .highIntensityIntervalTraining: String(localized: "HIIT")
        case .elliptical: String(localized: "Elliptical")
        case .rowing: String(localized: "Rowing")
        case .coreTraining: String(localized: "Core Training")
        case .flexibility: String(localized: "Flexibility")
        case .socialDance: String(localized: "Social Dance")
        case .cardioDance: String(localized: "Cardio Dance")
        case .pilates: String(localized: "Pilates")
        case .boxing: String(localized: "Boxing")
        case .martialArts: String(localized: "Martial Arts")
        case .wrestling: String(localized: "Wrestling")
        case .kickboxing: String(localized: "Kickboxing")
        case .fencing: String(localized: "Fencing")
        case .basketball: String(localized: "Basketball")
        case .soccer: String(localized: "Soccer")
        case .tennis: String(localized: "Tennis")
        case .badminton: String(localized: "Badminton")
        case .tableTennis: String(localized: "Table Tennis")
        case .volleyball: String(localized: "Volleyball")
        case .baseball: String(localized: "Baseball")
        case .softball: String(localized: "Softball")
        case .americanFootball: String(localized: "American Football")
        case .rugby: String(localized: "Rugby")
        case .hockey: String(localized: "Hockey")
        case .lacrosse: String(localized: "Lacrosse")
        case .cricket: String(localized: "Cricket")
        case .handball: String(localized: "Handball")
        case .racquetball: String(localized: "Racquetball")
        case .squash: String(localized: "Squash")
        case .pickleball: String(localized: "Pickleball")
        case .bowling: String(localized: "Bowling")
        case .golf: String(localized: "Golf")
        case .discSports: String(localized: "Disc Sports")
        case .australianFootball: String(localized: "Australian Football")
        case .gymnastics: String(localized: "Gymnastics")
        case .paddleSports: String(localized: "Paddle Sports")
        case .surfingSports: String(localized: "Surfing")
        case .waterFitness: String(localized: "Water Fitness")
        case .waterPolo: String(localized: "Water Polo")
        case .waterSports: String(localized: "Water Sports")
        case .sailing: String(localized: "Sailing")
        case .downhillSkiing: String(localized: "Skiing")
        case .snowboarding: String(localized: "Snowboarding")
        case .crossCountrySkiing: String(localized: "Cross-Country Skiing")
        case .snowSports: String(localized: "Snow Sports")
        case .skating: String(localized: "Skating")
        case .climbing: String(localized: "Climbing")
        case .mountaineering: String(localized: "Mountaineering")
        case .equestrianSports: String(localized: "Equestrian")
        case .fishing: String(localized: "Fishing")
        case .hunting: String(localized: "Hunting")
        case .archery: String(localized: "Archery")
        case .trackAndField: String(localized: "Track & Field")
        case .curling: String(localized: "Curling")
        case .jumpRope: String(localized: "Jump Rope")
        case .stairClimbing: String(localized: "Stair Climbing")
        case .stairStepper: String(localized: "Stair Stepper")
        case .stepTraining: String(localized: "Step Training")
        case .mixedCardio: String(localized: "Mixed Cardio")
        case .crossTraining: String(localized: "Cross Training")
        case .handCycling: String(localized: "Hand Cycling")
        case .taiChi: String(localized: "Tai Chi")
        case .mindAndBody: String(localized: "Mind & Body")
        case .barre: String(localized: "Barre")
        case .cooldown: String(localized: "Cooldown")
        case .preparationAndRecovery: String(localized: "Recovery")
        case .swimBikeRun: String(localized: "Triathlon")
        case .transition: String(localized: "Transition")
        case .fitnessGaming: String(localized: "Fitness Gaming")
        case .play: String(localized: "Play")
        case .underwaterDiving: String(localized: "Diving")
        case .wheelchairRunPace: String(localized: "Wheelchair Running")
        case .wheelchairWalkPace: String(localized: "Wheelchair Walking")
        case .other: String(localized: "Workout")
        }
    }

    /// Localizes exact generic activity names only; custom exercise titles remain untouched.
    /// The actual activity disambiguates historical names shared by Strength/Dance subtypes.
    static func localizedDisplayName(
        forStoredTitle storedTitle: String,
        preferredActivity: WorkoutActivityType? = nil
    ) -> String? {
        let normalized = storedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        func matches(_ activity: WorkoutActivityType) -> Bool {
            activity.typeName.caseInsensitiveCompare(normalized) == .orderedSame
                || activity.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
        }
        if let preferredActivity, matches(preferredActivity) {
            return preferredActivity.displayName
        }
        // These are exact generic machine/stairs titles, not substring inference.
        if normalized.caseInsensitiveCompare("Stair Climber") == .orderedSame {
            return WorkoutActivityType.stairClimbing.displayName
        }
        if normalized.caseInsensitiveCompare("Stairs") == .orderedSame {
            return WorkoutActivityType.stairStepper.displayName
        }
        if preferredActivity == .stairClimbing,
           ["계단 오르기", "스텝 클라이머", "스텝클라이머", "스텝밀", "천국의계단", "천국의 계단"].contains(normalized) {
            return WorkoutActivityType.stairClimbing.displayName
        }
        return allCases.first(where: matches)?.displayName
    }
}
