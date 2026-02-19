---
tags: [injury, wellness, body-part, muscle-group, train-integration, body-map]
date: 2026-02-19
category: brainstorm
status: draft
---

# Brainstorm: 부상 상태 기록 및 트레인 연동

## Problem Statement

운동 중 부상(발목 염좌, 허리 통증 등)을 체계적으로 기록하고 관리할 수단이 없다. 부상 상태를 모르고 운동하면 재부상 위험이 높아진다. 부상 기록을 트레인 탭의 운동 추천/경고 시스템과 연동하여 안전한 운동을 지원한다.

## Target Users

- 웨이트 트레이닝/운동을 하면서 부상 이력을 관리하고 싶은 사용자
- 부상 중 어떤 운동을 피해야 하는지 알고 싶은 사용자

## Success Criteria

1. Wellness 탭에서 부상을 생성/수정/종료/삭제할 수 있다
2. 활성 부상이 바디맵 + 카드 리스트로 시각화된다
3. Train 탭에서 활성 부상 부위와 관련된 운동 시 경고가 표시된다
4. 부상 이력(종료된 부상)을 조회할 수 있다

## Key Decisions

### 1. 부위 모델: BodyPart enum (신규) + MuscleGroup 매핑

기존 `MuscleGroup`(13개 근육군)은 관절(무릎, 발목, 팔꿈치)을 표현할 수 없다. 새로운 `BodyPart` enum을 만들고, 각 BodyPart가 영향을 미치는 MuscleGroup 목록을 매핑한다.

```swift
// Domain/Models/BodyPart.swift
enum BodyPart: String, Codable, CaseIterable {
    // 관절
    case neck           // 목
    case shoulder       // 어깨
    case elbow          // 팔꿈치
    case wrist          // 손목
    case lowerBack      // 허리
    case hip            // 고관절
    case knee           // 무릎
    case ankle          // 발목

    // 근육군 (기존 MuscleGroup과 1:1 대응)
    case chest
    case upperBack      // back + lats + traps
    case biceps
    case triceps
    case forearms
    case core
    case quadriceps
    case hamstrings
    case glutes
    case calves

    /// 이 부위의 부상이 영향을 미치는 MuscleGroup 목록
    var affectedMuscleGroups: [MuscleGroup] {
        switch self {
        case .neck:       return [.traps]
        case .shoulder:   return [.shoulders, .chest, .traps]
        case .elbow:      return [.biceps, .triceps, .forearms]
        case .wrist:      return [.forearms]
        case .lowerBack:  return [.back, .core]
        case .hip:        return [.glutes, .hamstrings, .quadriceps]
        case .knee:       return [.quadriceps, .hamstrings, .calves]
        case .ankle:      return [.calves]
        case .chest:      return [.chest]
        case .upperBack:  return [.back, .lats, .traps]
        case .biceps:     return [.biceps]
        case .triceps:    return [.triceps]
        case .forearms:   return [.forearms]
        case .core:       return [.core]
        case .quadriceps: return [.quadriceps]
        case .hamstrings: return [.hamstrings]
        case .glutes:     return [.glutes]
        case .calves:     return [.calves]
        }
    }

    /// 좌/우 구분이 필요한 부위
    var isLateral: Bool {
        switch self {
        case .shoulder, .elbow, .wrist, .hip, .knee, .ankle,
             .biceps, .triceps, .forearms, .quadriceps, .hamstrings, .glutes, .calves:
            return true
        case .neck, .lowerBack, .chest, .upperBack, .core:
            return false
        }
    }
}

enum BodySide: String, Codable {
    case left
    case right
    case both  // 양쪽 모두
}
```

### 2. 심각도: 3단계

```swift
enum InjurySeverity: Int, Codable, CaseIterable {
    case minor = 1     // 경미 — 주의하며 운동 가능
    case moderate = 2  // 보통 — 해당 부위 운동 자제 권장
    case severe = 3    // 심각 — 해당 부위 운동 금지
}
```

Train 탭 연동 시:
- **minor**: 노란 배지 정보 표시 ("Left ankle: minor injury")
- **moderate**: 주황 경고 ("Lower back moderate injury — exercise with caution")
- **severe**: 빨간 차단 경고 ("Right knee severe injury — avoid leg exercises")

### 3. SwiftData 모델

```swift
// Data/Persistence/Models/InjuryRecord.swift
@Model
final class InjuryRecord {
    var id: UUID
    var bodyPartRaw: String          // BodyPart.rawValue
    var bodySideRaw: String?         // BodySide.rawValue (nil = 해당 없음)
    var severityRaw: Int             // InjurySeverity.rawValue
    var startDate: Date
    var endDate: Date?               // nil = 활성 부상
    var memo: String
    var createdAt: Date

    // Computed
    var bodyPart: BodyPart { ... }
    var bodySide: BodySide? { ... }
    var severity: InjurySeverity { ... }
    var isActive: Bool { endDate == nil }
}
```

스키마: V4 → V5 (lightweight migration, 새 모델 추가만)

### 4. UI 구조

#### Wellness 탭 — 새 "Injuries" 섹션

기존 WellnessView 섹션 순서:
1. Sleep
2. Body Composition
3. **Injuries (신규)**

섹션 구성:
- **히어로 영역**: 바디맵 (기존 `MuscleRecoveryMapView` 패턴 활용, 부상 부위 하이라이트)
- **카드 리스트**: 활성 부상 카드 (부위, 심각도 배지, 기간, 메모 요약)
- **히스토리 링크**: "View Injury History" → 종료된 부상 목록

#### 부상 추가/수정 Sheet

```
┌─────────────────────────────┐
│  Add Injury                 │
│                             │
│  Body Part:  [Picker]       │
│  Side:       [L / R / Both] │  ← isLateral인 경우만 표시
│  Severity:   [● ●● ●●●]    │
│  Start Date: [DatePicker]   │
│  End Date:   [DatePicker]   │  ← Optional
│  Memo:       [TextField]    │
│                             │
│  [Save]                     │
└─────────────────────────────┘
```

### 5. Train 탭 연동

#### 5a. 운동 선택/실행 시 경고

`ActivityViewModel` 또는 운동 시작 플로우에서:
1. 활성 `InjuryRecord` 조회 (SwiftData `@Query`)
2. 선택한 운동의 `primaryMuscles + secondaryMuscles`와 활성 부상의 `affectedMuscleGroups` 교차 확인
3. 겹치면 severity에 따라 배너/경고 표시

```swift
// Domain/UseCases/CheckInjuryConflictUseCase.swift
struct InjuryConflict {
    let injury: InjuryInfo       // 부상 정보 (Domain DTO)
    let conflictingMuscles: [MuscleGroup]
}

func checkConflicts(
    exerciseMuscles: [MuscleGroup],
    activeInjuries: [InjuryInfo]
) -> [InjuryConflict]
```

#### 5b. MuscleRecoveryMapView 통합

기존 근육 피로도 맵에 부상 상태를 오버레이:
- 부상 부위에 경고 아이콘 또는 특수 색상(빨간 줄무늬 등) 표시
- 기존 fatigue 색상과 구분되는 시각적 처리

## Constraints

- **CloudKit**: `InjuryRecord`는 CloudKit sync 대상. Optional relationship 규칙 준수
- **바디맵**: 기존 `MuscleRecoveryMapView`의 SVG/Shape 패턴 활용 가능하나, 관절 부위는 새로운 핀/마커 방식 필요
- **레이어 경계**: `BodyPart`, `InjurySeverity`는 Domain. `InjuryRecord`는 Data. ViewModel은 SwiftData import 금지

## Edge Cases

1. **동일 부위 중복 부상**: 같은 부위에 활성 부상이 이미 있으면 경고 후 생성 허용 (다른 원인일 수 있음)
2. **종료일 < 시작일**: validation에서 차단
3. **활성 부상 0개**: 빈 상태 UI ("No active injuries" + 바디맵은 클린 상태)
4. **부상 기록 삭제**: CloudKit 전파 — 확인 다이얼로그 필수 (Correction #50)
5. **미래 시작일**: 허용하지 않음 (`startDate <= today`)

## Scope

### MVP (Must-have)
- [ ] `BodyPart` enum + `BodySide` enum (Domain)
- [ ] `InjurySeverity` enum (Domain)
- [ ] `InjuryRecord` SwiftData 모델 (Data, 스키마 V5)
- [ ] `InjuryViewModel` — CRUD + validation (Presentation)
- [ ] Wellness 탭 Injuries 섹션 — 카드 리스트 + 바디맵
- [ ] 부상 추가/수정 Sheet
- [ ] 부상 히스토리 화면 (종료된 부상)
- [ ] `CheckInjuryConflictUseCase` (Domain)
- [ ] Train 탭 운동 시 부상 경고 배너
- [ ] MuscleRecoveryMapView에 부상 오버레이
- [ ] 부상 통계 (부위별 빈도, 평균 회복 기간)
- [ ] 부상 기간 중 운동량 자동 비교 (부상 전/중/후)

### Nice-to-have (Future)
- [ ] Watch 앱에서 부상 상태 확인
- [ ] 부상 종료 리마인더 알림 (N일 경과 후 "회복되었나요?" 푸시)
- [ ] 사진 첨부 (부상 부위 사진 기록)

### 6. 바디맵 관절 시각화: Bullseye Ring Marker

**결정**: 근육 영역(filled region)과 시각적 언어를 분리하여 관절은 **불스아이 링 마커**(stroked circle + center dot)로 표현.

**대안 비교**:
- Radial gradient heat spots: 인접 관절 겹침, 근육 영역과 혼동 → 탈락
- SF Symbol icons: 16pt 이하 가독성 저하 → 탈락
- 연결 영역 하이라이트: 무릎/팔꿈치만 가능, 일반화 불가 → 탈락

**구현**: 기존 MuscleRecoveryMapView ZStack에 3번째 레이어 추가. 동일 724x1448 SVG 좌표계 사용.

**Severity별 마커**:
- minor: 노란 불스아이
- moderate: 주황 불스아이 + 미세 펄스
- severe: 빨간 불스아이 + 펄스 애니메이션

**관절 좌표 (SVG 724x1448 공간)**:

| Joint | Left (x, y) | Right (x, y) |
|-------|-------------|---------------|
| Shoulder | (218, 320) | (506, 320) |
| Elbow | (183, 530) | (541, 530) |
| Wrist | (127, 700) | (600, 700) |
| Hip | (310, 690) | (414, 690) |
| Knee | (290, 950) | (434, 950) |
| Ankle | (258, 1210) | (460, 1210) |

*좌표는 기존 SVG 경로 기반 추정값. 구현 시 실제 바디맵과 대조하여 미세 조정 필요.*

## Open Questions

(모두 해결됨)

## Next Steps

- [ ] `/plan injury-tracking`으로 구현 계획 생성
