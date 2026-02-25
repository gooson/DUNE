import SwiftUI

extension WorkoutActivityType {

    /// Korean display name for the activity type.
    var displayName: String {
        switch self {
        case .running: "러닝"
        case .walking: "걷기"
        case .cycling: "사이클링"
        case .swimming: "수영"
        case .hiking: "하이킹"
        case .yoga: "요가"
        case .traditionalStrengthTraining: "웨이트 트레이닝"
        case .functionalStrengthTraining: "기능성 근력"
        case .highIntensityIntervalTraining: "HIIT"
        case .elliptical: "일립티컬"
        case .rowing: "로잉"
        case .coreTraining: "코어"
        case .flexibility: "유연성"
        case .socialDance: "소셜 댄스"
        case .cardioDance: "카디오 댄스"
        case .pilates: "필라테스"
        case .boxing: "복싱"
        case .martialArts: "무술"
        case .wrestling: "레슬링"
        case .kickboxing: "킥복싱"
        case .fencing: "펜싱"
        case .basketball: "농구"
        case .soccer: "축구"
        case .tennis: "테니스"
        case .badminton: "배드민턴"
        case .tableTennis: "탁구"
        case .volleyball: "배구"
        case .baseball: "야구"
        case .softball: "소프트볼"
        case .americanFootball: "미식축구"
        case .rugby: "럭비"
        case .hockey: "하키"
        case .lacrosse: "라크로스"
        case .cricket: "크리켓"
        case .handball: "핸드볼"
        case .racquetball: "라켓볼"
        case .squash: "스쿼시"
        case .pickleball: "피클볼"
        case .bowling: "볼링"
        case .golf: "골프"
        case .discSports: "디스크"
        case .australianFootball: "호주식 축구"
        case .gymnastics: "체조"
        case .paddleSports: "패들 스포츠"
        case .surfingSports: "서핑"
        case .waterFitness: "수중 피트니스"
        case .waterPolo: "수구"
        case .waterSports: "수상 스포츠"
        case .sailing: "세일링"
        case .downhillSkiing: "스키"
        case .snowboarding: "스노보드"
        case .crossCountrySkiing: "크로스컨트리 스키"
        case .snowSports: "스노 스포츠"
        case .skating: "스케이팅"
        case .climbing: "클라이밍"
        case .mountaineering: "등산"
        case .equestrianSports: "승마"
        case .fishing: "낚시"
        case .hunting: "사냥"
        case .archery: "양궁"
        case .trackAndField: "육상"
        case .curling: "컬링"
        case .jumpRope: "줄넘기"
        case .stairClimbing: "계단 오르기"
        case .stairStepper: "계단 오르기"
        case .stepTraining: "스텝 트레이닝"
        case .mixedCardio: "혼합 유산소"
        case .crossTraining: "크로스 트레이닝"
        case .handCycling: "핸드 사이클링"
        case .taiChi: "태극권"
        case .mindAndBody: "심신 수련"
        case .barre: "바레"
        case .cooldown: "쿨다운"
        case .preparationAndRecovery: "회복"
        case .swimBikeRun: "트라이애슬론"
        case .transition: "전환"
        case .fitnessGaming: "피트니스 게임"
        case .play: "놀이"
        case .underwaterDiving: "다이빙"
        case .wheelchairRunPace: "휠체어 러닝"
        case .wheelchairWalkPace: "휠체어 걷기"
        case .other: "운동"
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

    /// Category-based color for the activity type.
    var color: Color {
        switch category {
        case .cardio: DS.Color.activity
        case .strength: .orange
        case .mindBody: .purple
        case .dance: .pink
        case .combat: .red
        case .sports: .blue
        case .water: .cyan
        case .winter: .indigo
        case .outdoor: .green
        case .multiSport: DS.Color.activity
        case .other: .gray
        }
    }
}

extension ActivityCategory {
    /// Korean display name for the category.
    var displayName: String {
        switch self {
        case .cardio: "유산소"
        case .strength: "근력"
        case .mindBody: "심신"
        case .dance: "댄스"
        case .combat: "격투"
        case .sports: "스포츠"
        case .water: "수상"
        case .winter: "겨울"
        case .outdoor: "아웃도어"
        case .multiSport: "멀티"
        case .other: "기타"
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
    /// Korean display name.
    var displayName: String {
        switch self {
        case .fastestPace: "최고 페이스"
        case .longestDistance: "최장 거리"
        case .highestCalories: "최고 칼로리"
        case .longestDuration: "최장 시간"
        case .highestElevation: "최고 고도"
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
        case .strengthWeight: "근력 중량"
        case .fastestPace: "최고 페이스"
        case .longestDistance: "최장 거리"
        case .highestCalories: "최고 칼로리"
        case .longestDuration: "최장 시간"
        case .highestElevation: "최고 고도"
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
