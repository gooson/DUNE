import SwiftUI

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
        case .highIntensityIntervalTraining: "HIIT"
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

    /// SF Symbol name for the activity type.
    var iconName: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .yoga: "figure.yoga"
        case .traditionalStrengthTraining: "dumbbell.fill"
        case .functionalStrengthTraining: "figure.strengthtraining.functional"
        case .highIntensityIntervalTraining: "figure.highintensity.intervaltraining"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .coreTraining: "figure.core.training"
        case .flexibility: "figure.flexibility"
        case .socialDance, .cardioDance: "figure.dance"
        case .pilates: "figure.pilates"
        case .boxing: "figure.boxing"
        case .martialArts: "figure.martial.arts"
        case .wrestling: "figure.wrestling"
        case .kickboxing: "figure.kickboxing"
        case .fencing: "figure.fencing"
        case .basketball: "figure.basketball"
        case .soccer: "figure.soccer"
        case .tennis: "figure.tennis"
        case .badminton: "figure.badminton"
        case .tableTennis: "figure.table.tennis"
        case .volleyball: "figure.volleyball"
        case .baseball: "figure.baseball"
        case .softball: "figure.softball"
        case .americanFootball: "figure.american.football"
        case .rugby: "figure.rugby"
        case .hockey: "figure.hockey"
        case .lacrosse: "figure.lacrosse"
        case .cricket: "figure.cricket"
        case .handball: "figure.handball"
        case .racquetball: "figure.racquetball"
        case .squash: "figure.squash"
        case .pickleball: "figure.pickleball"
        case .bowling: "figure.bowling"
        case .golf: "figure.golf"
        case .discSports: "figure.disc.sports"
        case .australianFootball: "figure.australian.football"
        case .gymnastics: "figure.gymnastics"
        case .paddleSports: "oar.2.crossed"
        case .surfingSports: "figure.surfing"
        case .waterFitness: "figure.water.fitness"
        case .waterPolo: "figure.waterpolo"
        case .waterSports: "figure.water.fitness"
        case .sailing: "sailboat.fill"
        case .downhillSkiing: "figure.skiing.downhill"
        case .snowboarding: "figure.snowboarding"
        case .crossCountrySkiing: "figure.skiing.crosscountry"
        case .snowSports: "snowflake"
        case .skating: "figure.skating"
        case .climbing: "figure.climbing"
        case .mountaineering: "mountain.2.fill"
        case .equestrianSports: "figure.equestrian.sports"
        case .fishing: "figure.fishing"
        case .hunting: "scope"
        case .archery: "figure.archery"
        case .trackAndField: "figure.track.and.field"
        case .curling: "figure.curling"
        case .jumpRope: "figure.jumprope"
        case .stairClimbing: "figure.stairs"
        case .stairStepper: "figure.stair.stepper"
        case .stepTraining: "figure.step.training"
        case .mixedCardio: "figure.mixed.cardio"
        case .crossTraining: "figure.cross.training"
        case .handCycling: "figure.hand.cycling"
        case .taiChi: "figure.taichi"
        case .mindAndBody: "figure.mind.and.body"
        case .barre: "figure.barre"
        case .cooldown: "figure.cooldown"
        case .preparationAndRecovery: "figure.cooldown"
        case .swimBikeRun: "figure.open.water.swim"
        case .transition: "arrow.triangle.2.circlepath"
        case .fitnessGaming: "gamecontroller.fill"
        case .play: "figure.play"
        case .underwaterDiving: "water.waves"
        case .wheelchairRunPace: "figure.roll.runningpace"
        case .wheelchairWalkPace: "figure.roll"
        case .other: "figure.mixed.cardio"
        }
    }

    /// Category-based color for the activity type (Desert Horizon palette).
    var color: Color { category.color }
}

extension ActivityCategory {
    /// Desert Horizon palette color for the category.
    var color: Color {
        switch self {
        case .cardio: DS.Color.activityCardio
        case .strength: DS.Color.activityStrength
        case .mindBody: DS.Color.activityMindBody
        case .dance: DS.Color.activityDance
        case .combat: DS.Color.activityCombat
        case .sports: DS.Color.activitySports
        case .water: DS.Color.activityWater
        case .winter: DS.Color.activityWinter
        case .outdoor: DS.Color.activityOutdoor
        case .multiSport: DS.Color.activityCardio
        case .other: DS.Color.activityOther
        }
    }

    /// Localized display name for the category.
    var displayName: String {
        switch self {
        case .cardio: String(localized: "Cardio")
        case .strength: String(localized: "Strength")
        case .mindBody: String(localized: "Mind & Body")
        case .dance: String(localized: "Dance")
        case .combat: String(localized: "Combat")
        case .sports: String(localized: "Sports")
        case .water: String(localized: "Water")
        case .winter: String(localized: "Winter")
        case .outdoor: String(localized: "Outdoor")
        case .multiSport: String(localized: "Multi Sport")
        case .other: String(localized: "Other")
        }
    }
}

extension MilestoneDistance {
    /// SF Symbol for the milestone badge.
    var iconName: String { "medal.fill" }

    /// Badge color.
    var color: Color {
        switch self {
        case .fiveK: DS.Color.activity
        case .tenK: .blue
        case .halfMarathon: .purple
        case .marathon: .orange
        }
    }
}

extension PersonalRecordType {
    /// Localized display name.
    var displayName: String {
        switch self {
        case .fastestPace: String(localized: "Fastest Pace")
        case .longestDistance: String(localized: "Longest Distance")
        case .highestCalories: String(localized: "Highest Calories")
        case .longestDuration: String(localized: "Longest Duration")
        case .highestElevation: String(localized: "Highest Elevation")
        }
    }

    /// SF Symbol for the record type.
    var iconName: String {
        switch self {
        case .fastestPace: "speedometer"
        case .longestDistance: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .highestCalories: "flame.fill"
        case .longestDuration: "timer"
        case .highestElevation: "mountain.2.fill"
        }
    }
}

extension ActivityPersonalRecord.Kind {
    var displayName: String {
        switch self {
        case .strengthWeight: String(localized: "Strength Weight")
        case .fastestPace: String(localized: "Fastest Pace")
        case .longestDistance: String(localized: "Longest Distance")
        case .highestCalories: String(localized: "Highest Calories")
        case .longestDuration: String(localized: "Longest Duration")
        case .highestElevation: String(localized: "Highest Elevation")
        }
    }

    var iconName: String {
        switch self {
        case .strengthWeight: "dumbbell.fill"
        case .fastestPace: "speedometer"
        case .longestDistance: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .highestCalories: "flame.fill"
        case .longestDuration: "timer"
        case .highestElevation: "mountain.2.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .strengthWeight: .orange
        case .fastestPace: DS.Color.activity
        case .longestDistance: DS.Color.activity
        case .highestCalories: .orange
        case .longestDuration: DS.Color.fitness
        case .highestElevation: .green
        }
    }
}
