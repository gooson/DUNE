import HealthKit

extension WorkoutActivityType {

    /// Maps from HKWorkoutActivityType to the domain enum.
    init(healthKit hk: HKWorkoutActivityType) {
        switch hk {
        case .running:                          self = .running
        case .walking:                          self = .walking
        case .cycling:                          self = .cycling
        case .swimming:                         self = .swimming
        case .hiking:                           self = .hiking
        case .yoga:                             self = .yoga
        case .traditionalStrengthTraining:      self = .traditionalStrengthTraining
        case .functionalStrengthTraining:       self = .functionalStrengthTraining
        case .highIntensityIntervalTraining:    self = .highIntensityIntervalTraining
        case .elliptical:                       self = .elliptical
        case .rowing:                           self = .rowing
        case .coreTraining:                     self = .coreTraining
        case .flexibility:                      self = .flexibility
        case .pilates:                          self = .pilates
        case .boxing:                           self = .boxing
        case .martialArts:                      self = .martialArts
        case .wrestling:                        self = .wrestling
        case .kickboxing:                       self = .kickboxing
        case .fencing:                          self = .fencing
        case .basketball:                       self = .basketball
        case .soccer:                           self = .soccer
        case .tennis:                           self = .tennis
        case .badminton:                        self = .badminton
        case .tableTennis:                      self = .tableTennis
        case .volleyball:                       self = .volleyball
        case .baseball:                         self = .baseball
        case .softball:                         self = .softball
        case .americanFootball:                 self = .americanFootball
        case .rugby:                            self = .rugby
        case .hockey:                           self = .hockey
        case .lacrosse:                         self = .lacrosse
        case .cricket:                          self = .cricket
        case .handball:                         self = .handball
        case .racquetball:                      self = .racquetball
        case .squash:                           self = .squash
        case .bowling:                          self = .bowling
        case .golf:                             self = .golf
        case .discSports:                       self = .discSports
        case .australianFootball:               self = .australianFootball
        case .paddleSports:                     self = .paddleSports
        case .surfingSports:                    self = .surfingSports
        case .waterFitness:                     self = .waterFitness
        case .waterPolo:                        self = .waterPolo
        case .waterSports:                      self = .waterSports
        case .sailing:                          self = .sailing
        case .downhillSkiing:                   self = .downhillSkiing
        case .snowboarding:                     self = .snowboarding
        case .crossCountrySkiing:               self = .crossCountrySkiing
        case .snowSports:                       self = .snowSports
        case .climbing:                         self = .climbing
        case .equestrianSports:                 self = .equestrianSports
        case .fishing:                          self = .fishing
        case .hunting:                          self = .hunting
        case .archery:                          self = .archery
        case .trackAndField:                    self = .trackAndField
        case .curling:                          self = .curling
        case .jumpRope:                         self = .jumpRope
        case .stairClimbing:                    self = .stairClimbing
        case .stairs:                           self = .stairStepper
        case .stepTraining:                     self = .stepTraining
        case .mixedCardio:                      self = .mixedCardio
        case .crossTraining:                    self = .crossTraining
        case .handCycling:                      self = .handCycling
        case .socialDance:                      self = .socialDance
        case .cardioDance:                      self = .cardioDance
        case .taiChi:                           self = .taiChi
        case .mindAndBody:                      self = .mindAndBody
        case .barre:                            self = .barre
        case .cooldown:                         self = .cooldown
        case .preparationAndRecovery:           self = .preparationAndRecovery
        case .fitnessGaming:                    self = .fitnessGaming
        case .play:                             self = .play
        case .underwaterDiving:                 self = .underwaterDiving
        case .wheelchairRunPace:                self = .wheelchairRunPace
        case .wheelchairWalkPace:               self = .wheelchairWalkPace
        case .pickleball:                       self = .pickleball
        case .swimBikeRun:                      self = .swimBikeRun
        case .transition:                       self = .transition
        @unknown default:                       self = .other
        }
    }

    /// Maps back to HKWorkoutActivityType for writing workouts.
    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .running:                          .running
        case .walking:                          .walking
        case .cycling:                          .cycling
        case .swimming:                         .swimming
        case .hiking:                           .hiking
        case .yoga:                             .yoga
        case .traditionalStrengthTraining:      .traditionalStrengthTraining
        case .functionalStrengthTraining:       .functionalStrengthTraining
        case .highIntensityIntervalTraining:    .highIntensityIntervalTraining
        case .elliptical:                       .elliptical
        case .rowing:                           .rowing
        case .coreTraining:                     .coreTraining
        case .flexibility:                      .flexibility
        case .pilates:                          .pilates
        case .boxing:                           .boxing
        case .martialArts:                      .martialArts
        case .wrestling:                        .wrestling
        case .kickboxing:                       .kickboxing
        case .fencing:                          .fencing
        case .basketball:                       .basketball
        case .soccer:                           .soccer
        case .tennis:                           .tennis
        case .badminton:                        .badminton
        case .tableTennis:                      .tableTennis
        case .volleyball:                       .volleyball
        case .baseball:                         .baseball
        case .softball:                         .softball
        case .americanFootball:                 .americanFootball
        case .rugby:                            .rugby
        case .hockey:                           .hockey
        case .lacrosse:                         .lacrosse
        case .cricket:                          .cricket
        case .handball:                         .handball
        case .racquetball:                      .racquetball
        case .squash:                           .squash
        case .bowling:                          .bowling
        case .golf:                             .golf
        case .discSports:                       .discSports
        case .australianFootball:               .australianFootball
        case .paddleSports:                     .paddleSports
        case .surfingSports:                    .surfingSports
        case .waterFitness:                     .waterFitness
        case .waterPolo:                        .waterPolo
        case .waterSports:                      .waterSports
        case .sailing:                          .sailing
        case .downhillSkiing:                   .downhillSkiing
        case .snowboarding:                     .snowboarding
        case .crossCountrySkiing:               .crossCountrySkiing
        case .snowSports:                       .snowSports
        case .climbing:                         .climbing
        case .equestrianSports:                 .equestrianSports
        case .fishing:                          .fishing
        case .hunting:                          .hunting
        case .archery:                          .archery
        case .trackAndField:                    .trackAndField
        case .curling:                          .curling
        case .jumpRope:                         .jumpRope
        case .stairClimbing:                    .stairClimbing
        case .stairStepper:                     .stairs
        case .stepTraining:                     .stepTraining
        case .mixedCardio:                      .mixedCardio
        case .crossTraining:                    .crossTraining
        case .handCycling:                      .handCycling
        case .socialDance:                      .socialDance
        case .cardioDance:                      .cardioDance
        case .taiChi:                           .taiChi
        case .mindAndBody:                      .mindAndBody
        case .barre:                            .barre
        case .cooldown:                         .cooldown
        case .preparationAndRecovery:           .preparationAndRecovery
        case .fitnessGaming:                    .fitnessGaming
        case .play:                             .play
        case .underwaterDiving:                 .underwaterDiving
        case .wheelchairRunPace:                .wheelchairRunPace
        case .wheelchairWalkPace:               .wheelchairWalkPace
        case .pickleball:                       .pickleball
        case .swimBikeRun:                      .swimBikeRun
        case .transition:                       .transition
        case .mountaineering:                   .hiking
        case .skating:                          .other
        case .other:                            .other
        }
    }
}
