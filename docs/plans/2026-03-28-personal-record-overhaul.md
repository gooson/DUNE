---
tags: [personal-record, 1rm, strength, chart, activity-tab]
date: 2026-03-28
category: plan
status: draft
---

# Plan: Personal Record System Overhaul

## Summary

Activity 탭의 퍼스널 레코드를 1RM/렙PR/볼륨PR로 확장하고, 기존 차트 패턴과 동일한 타임라인 뷰로 리뉴얼합니다.

## Key Discovery: OneRMEstimationService 이미 존재

`OneRMEstimationService`가 Epley/Brzycki/Lombardi 공식과 히스토리 계산을 이미 구현. `OneRMAnalysisSection`이 운동별 상세에서 1RM을 표시 중. 이 인프라를 PR 시스템에 통합합니다.

## Affected Files

### Domain Layer (신규/수정)

| File | Action | Description |
|------|--------|-------------|
| `Domain/Models/StrengthPersonalRecord.swift` | **수정** | 1RM, repMax, volume 필드 추가 |
| `Domain/Models/ActivityPersonalRecord.swift` | **수정** | Kind에 estimated1RM, repMax, sessionVolume 추가 |
| `Domain/UseCases/StrengthPRService.swift` | **수정** | set-level 입력 받아 1RM/렙PR/볼륨PR 추출 |
| `Domain/UseCases/ActivityPersonalRecordService.swift` | **수정** | 새 Kind 병합 로직 |

### Presentation Layer (수정)

| File | Action | Description |
|------|--------|-------------|
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | **수정** | DotLineChart 패턴 + 기간 선택 추가 |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | **수정** | 기간별 필터링, 차트 데이터 생성 |
| `Presentation/Activity/Components/PersonalRecordsSection.swift` | **수정** | 새 Kind 카드 표시 |
| `Presentation/Activity/ActivityViewModel.swift` | **수정** | set-level 데이터 PR 서비스에 전달 |
| `Presentation/Shared/Extensions/ExerciseRecord+Snapshot.swift` | **수정** | set-level 스냅샷 추가 |
| `Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | **수정** | PR 달성 축하 섹션 추가 |

### Presentation Extensions (수정)

| File | Action | Description |
|------|--------|-------------|
| `Presentation/Shared/Extensions/WorkoutActivityType+View.swift` | **수정** | 새 Kind의 displayName, iconName, tintColor |

### Localization

| File | Action | Description |
|------|--------|-------------|
| `Shared/Resources/Localizable.xcstrings` | **수정** | 새 문자열 en/ko/ja 추가 |

### Tests (신규/수정)

| File | Action | Description |
|------|--------|-------------|
| `DUNETests/StrengthPRServiceTests.swift` | **수정** | 1RM/렙PR/볼륨PR 테스트 추가 |
| `DUNETests/ActivityPersonalRecordServiceTests.swift` | **수정** | 새 Kind 병합 테스트 |
| `DUNETests/PersonalRecordsDetailViewModelTests.swift` | **수정** | 기간 필터링 테스트 |

## Implementation Steps

### Step 1: Domain 모델 확장 (StrengthPersonalRecord + Kind)

**StrengthPersonalRecord 확장**:
- `estimated1RM: Double?` — Epley 1RM 추정치
- `repMaxEntries: [RepMaxEntry]` — 렙수별 최고 중량
- `sessionVolume: Double?` — 세션 총 볼륨

```swift
struct RepMaxEntry: Sendable, Hashable {
    let reps: Int  // 3, 5, 10
    let weight: Double
    let date: Date
}
```

**ActivityPersonalRecord.Kind 확장**:
- `.estimated1RM` — 추정 1RM
- `.repMax` — 렙 레인지별 최고 중량 (subtitle에 "3RM", "5RM" 등)
- `.sessionVolume` — 세션 총 볼륨 (weight × reps 합계)

**Verification**: 컴파일 + 기존 테스트 통과

### Step 2: StrengthPRService set-level 입력 확장

**현재**: `WorkoutEntry(exerciseName, date, bestWeight)` — 평균 중량만
**변경**: set-level 데이터를 받아 1RM/렙PR/볼륨 계산

```swift
struct SetEntry: Sendable {
    let weight: Double
    let reps: Int
}

struct WorkoutEntry: Sendable {
    let exerciseName: String
    let date: Date
    let sets: [SetEntry]  // 새로 추가 (기존 bestWeight은 backward compat)
    let bestWeight: Double  // 기존 유지
}
```

**추출 로직**:
1. **1RM**: 각 세트의 `OneRMFormula.epley.estimate(weight:reps:)` → 운동별 최고값
2. **렙 PR**: reps == 3/5/10인 세트 중 최고 weight → `RepMaxEntry`
3. **볼륨**: 운동별 세션 Σ(weight × reps) → 최고 세션 볼륨

**Validation**: weight 0-500, reps 1-30, 1RM <= 750 (Epley 최대), volume <= 100000

**Verification**: 유닛 테스트 - 1RM 계산 정확도, 렙PR 필터링, 볼륨 합산

### Step 3: ActivityPersonalRecordService 병합 로직 업데이트

- `merge()` 메서드에 새 Kind 지원 추가
- `isValid()` 범위에 `.estimated1RM`, `.repMax`, `.sessionVolume` 추가
- 정렬: Kind.sortOrder 업데이트 (1RM → repMax → volume → strength → cardio)

**Verification**: 유닛 테스트 - 새 Kind 포함 병합, 정렬 순서

### Step 4: ExerciseRecord+Snapshot set-level 데이터 추가

**ExerciseRecordSnapshot 확장**:
```swift
struct SetSnapshot: Sendable {
    let weight: Double
    let reps: Int
}
var completedSetSnapshots: [SetSnapshot]
```

`ExerciseRecord.snapshot()` → `completedSets`에서 weight+reps 추출

### Step 5: ActivityViewModel set-level PR 연결

`recomputePersonalRecordsOnly()`에서:
1. `exerciseRecordSnapshots`에서 `completedSetSnapshots` 읽기
2. `StrengthPRService.WorkoutEntry`에 `sets` 전달
3. 새 타입 PR이 `personalRecords`에 포함되어 UI에 표시

### Step 6: PersonalRecordsDetailView 차트 리뉴얼

**기존**: 단순 PointMark 차트 (기간 선택 없음)
**변경**: DotLineChart 패턴 + 기간 선택

1. `TimePeriod` 기반 기간 선택 Picker (week/month/3month/6month/year)
2. 기간별 필터링된 레코드로 DotLineChart 렌더링
3. `.id(period)` + `.transition(.opacity)` 전환
4. Y축 단위: Kind별 formatter (기존 `chartAxisValue` 확장)
5. Summary stats: 현재 PR, 이전 대비 delta, 마지막 달성일

**Verification**: 빌드 성공, 시뮬레이터에서 차트 렌더링

### Step 7: PersonalRecordsDetailViewModel 기간 필터링

```swift
@Observable
final class PersonalRecordsDetailViewModel {
    var personalRecords: [ActivityPersonalRecord] = []
    var selectedPeriod: TimePeriod = .month
    var selectedKind: ActivityPersonalRecord.Kind?

    var filteredRecords: [ActivityPersonalRecord] { ... }  // kind + period
    var chartData: [ActivityPersonalRecord] { ... }  // date ascending
    var currentBest: ActivityPersonalRecord? { ... }
    var previousBest: ActivityPersonalRecord? { ... }  // delta 계산용
}
```

### Step 8: PersonalRecordsSection 새 Kind 카드

- `.estimated1RM` → 트로피 아이콘, "Est. 1RM", kg 단위
- `.repMax` → 웨이트 아이콘, "5RM" subtitle, kg 단위
- `.sessionVolume` → 차트 아이콘, "Volume", kg 단위

### Step 9: WorkoutCompletionSheet PR 축하 섹션

기존 `WorkoutCompletionSheet`에 조건부 PR 섹션 추가:
- 세션에서 달성한 PR 목록 (1RM, 렙PR, 볼륨 등)
- 각 PR: 아이콘 + 운동명 + 새 값 + delta (이전 대비 향상폭)
- 달성 PR이 없으면 섹션 숨김

### Step 10: Localization

새 문자열 en/ko/ja 3개 언어 등록:
- "Est. 1RM" / "추정 1RM" / "推定1RM"
- "3RM", "5RM", "10RM" — 국제 표준 (번역 불필요)
- "Session Volume" / "세션 볼륨" / "セッション総量"
- "New PR!" / "새 기록!" / "新記録！"
- Period labels는 기존 TimePeriod 재사용

### Step 11: 유닛 테스트

1. `StrengthPRServiceTests` — 1RM 추출, 렙PR 추출, 볼륨PR 추출, 에지 케이스
2. `ActivityPersonalRecordServiceTests` — 새 Kind 병합, 정렬
3. `PersonalRecordsDetailViewModelTests` — 기간 필터링, 베스트/delta 계산

## Test Strategy

| 테스트 유형 | 대상 | 검증 항목 |
|------------|------|----------|
| Unit | StrengthPRService | 1RM Epley 정확도, 렙PR 필터, 볼륨 합산, validation |
| Unit | ActivityPersonalRecordService | 새 Kind 병합, 정렬 순서, isValid 범위 |
| Unit | PersonalRecordsDetailViewModel | 기간 필터링, best/delta 계산 |
| UI | PersonalRecordsDetailView | 차트 렌더링, 기간 전환, 새 Kind 카드 표시 |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| set-level 데이터 없는 레거시 레코드 | 1RM/렙PR 계산 불가 | bestWeight fallback 유지 (기존 strengthWeight) |
| 1RM 추정치 > 500kg | isValid 통과 불가 | `.estimated1RM` validation 범위를 750으로 설정 |
| bodyweight 운동 volume = 0 | 무의미한 PR | weight > 0 조건으로 bodyweight 제외 |
| ExerciseRecordSnapshot 변경 | 다른 소비자 영향 | 기존 필드 유지, 새 필드 추가만 |

## Edge Cases

1. **레거시 ExerciseRecord (sets 없음)**: `completedSetSnapshots` 빈 배열 → 기존 bestWeight PR만
2. **1렙 세트**: Epley 공식에서 1RM = weight 그대로 (올바른 동작)
3. **0 weight 세트**: 1RM/렙PR/볼륨 계산에서 제외
4. **30렙 초과**: OneRMFormula가 reps 1-30만 허용 → nil 반환 → 해당 세트 제외
5. **동일 운동 복수 세션 같은 날**: 각 세션 독립 볼륨 PR, 1RM은 전체 중 최고값
