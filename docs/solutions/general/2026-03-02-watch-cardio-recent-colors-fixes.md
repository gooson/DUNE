---
tags: [watchos, cardio, healthkit, dedup, asset-catalog, colors, recent-workouts]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/Domain/Models/WorkoutActivityType.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNE/Presentation/Activity/Components/ExerciseListSection.swift
  - DUNETests/CardioWorkoutModeTests.swift
  - DUNETests/ExerciseViewModelTests.swift
  - Shared/Resources/Colors.xcassets/ForestAccent.colorset/Contents.json
  - Shared/Resources/Colors.xcassets/OceanAccent.colorset/Contents.json
related_solutions:
  - docs/solutions/general/2026-03-02-watchos-button-overflow-fix.md
  - docs/solutions/healthkit/2026-02-26-watch-workout-dedup-false-positive.md
  - docs/solutions/architecture/2026-03-02-shared-colors-xcassets.md
---

# Solution: Watch Cardio Start + Recent Workouts + Theme Color Asset Fix

## Problem

watch 앱에서 세 가지 회귀가 동시에 관측되었다.

### Symptoms

- 단일 운동(걷기 계열) 진입 시 Outdoor/Indoor 선택 이후 세션 시작이 진행되지 않거나 잘못된 분기로 진입
- Activity 화면 Recent Workouts에 watch에서 기록한 러닝이 누락
- watch 런타임 로그에 `No color named 'ForestAccent' found in asset catalog`가 반복 출력

### Root Cause

1. **카디오 분기 오탐**: ID stem 기반 추론(`walking-lunge` → `walking`)이 input type 문맥 없이 동작해 비카디오 운동이 카디오 경로로 잘못 분기됨.
2. **Recent dedup 기준 불일치**: compact recent 리스트는 set 데이터가 있는 manual record만 렌더링하지만, dedup은 전체 manual record를 기준으로 적용되어 no-set record가 HealthKit cardio row를 숨길 수 있었음.
3. **watch 색상 asset 해석 누락**: 다수 Forest/Ocean colorset의 첫 항목이 light appearance 전용으로만 정의되어 watch 번들에서 기본 color lookup이 실패하는 케이스가 발생.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutActivityType.swift` | `resolveDistanceBased`에 `inputTypeRaw` 파라미터 및 cardio input type guard 추가 | stem 오탐 방지 |
| `WorkoutPreviewView.swift` | watch exercise library에서 canonical ID 기반 inputType 조회 후 resolve 호출 | 분기 정확도 향상 |
| `ExerciseListSection.swift` | `recentListDedupRecords(from:)` 도입, compact dedup을 set 기반 record로 한정 | 렌더링/중복제거 기준 정합 |
| `CardioWorkoutModeTests.swift` | non-cardio inputType guard 및 cardio 허용 케이스 테스트 추가 | 회귀 방지 |
| `ExerciseViewModelTests.swift` | no-set manual record가 HK cardio를 숨기지 않는 테스트 추가 | dedup 회귀 방지 |
| `Shared/Resources/Colors.xcassets/*Forest*/*Ocean*/Contents.json` | 첫 color entry를 universal 기본값으로 정규화 | watch 색상 lookup 안정화 |

### Key Code

```swift
static func resolveDistanceBased(
    from id: String,
    name: String,
    inputTypeRaw: String? = nil
) -> WorkoutActivityType? {
    if let inputTypeRaw,
       !inputTypeRaw.isEmpty,
       !cardioInputTypes.contains(inputTypeRaw) {
        return nil
    }
    // direct rawValue -> stem -> name inference
}
```

```swift
func recentListDedupRecords(from records: [ExerciseRecord]) -> [ExerciseRecord] {
    records.filter(\.hasSetData)
}
```

```json
{
  "colors": [
    { "idiom": "universal", "color": { "...": "light value" } },
    { "idiom": "universal", "appearances": [{ "appearance": "luminosity", "value": "dark" }], "color": { "...": "dark value" } }
  ]
}
```

## Prevention

### Checklist Addition

- [ ] watch cardio 판별은 ID/name 추론 전에 `inputType` 문맥을 우선 검증
- [ ] dedup 로직은 “실제 렌더링 대상”과 동일한 집합을 기준으로 적용
- [ ] shared colorset 작성 시 첫 항목은 universal 기본값으로 유지
- [ ] watch에서 색상 누락 로그가 보이면 `Assets.car`에 실제 심볼 포함 여부를 먼저 확인

### Rule Addition (if applicable)

- 기존 `healthkit-patterns.md`, `watch-navigation.md`, `documentation-standards.md` 범위 내에서 처리 가능하여 신규 룰 파일 추가는 생략.

## Lessons Learned

- watch cardio 분기는 운동명/ID 기반 휴리스틱만으로는 불충분하며 input type 메타데이터를 결합해야 안정적이다.
- dedup은 “데이터 관점 정합”뿐 아니라 “UI 표시 관점 정합”을 동시에 맞춰야 누락 회귀를 막을 수 있다.
- colorset light/dark variant 구성은 플랫폼별 asset compiler 결과가 달라질 수 있어, universal 기본값을 명시하는 패턴이 가장 안전하다.
