---
topic: watch-cardio-recent-colors-fixes
date: 2026-03-02
category: plan
status: implemented
confidence: high
tags: [watchos, cardio, dedup, healthkit, asset-catalog, colors]
related_solutions:
  - docs/solutions/general/2026-03-02-watchos-button-overflow-fix.md
  - docs/solutions/healthkit/2026-02-26-watch-workout-dedup-false-positive.md
  - docs/solutions/architecture/2026-03-02-shared-colors-xcassets.md
related_brainstorms: []
---

# Implementation Plan: Watch Cardio + Recent + Color Asset Fixes

## Context

Watch에서 단일 운동(걷기 변형 포함) 시작 시 유산소/근력 분기 오탐으로 시작 플로우가 막히고, Activity Recent 리스트에서 watch 러닝이 누락되며, watch 런타임에서 `ForestAccent` 색상 미로딩 로그가 대량 발생했다. 세 문제는 각각 워치 분기 로직, dedup 기준 범위, colorset variant 정의의 결함으로 분리 대응이 필요했다.

## Requirements

### Functional

- watch 단일 운동 시작 시 비카디오 운동이 카디오로 오탐되지 않아야 한다.
- Activity Recent Workouts에서 watch HealthKit 러닝이 조건 충족 시 정상 노출되어야 한다.
- watch 런타임에서 `No color named 'ForestAccent'` 로그가 발생하지 않아야 한다.

### Non-functional

- Domain/Watch 레이어 경계를 유지한다.
- 기존 카디오 시작 UX(Outdoor/Indoor 선택)와 근력 시작 UX를 보존한다.
- 회귀 방지를 위한 단위 테스트를 추가한다.

## Approach

문제를 세 축으로 분리해 최소 침습 수정을 적용한다.

1. **카디오 분기 정확도 개선**: `WorkoutActivityType.resolveDistanceBased`에 `inputTypeRaw` 가드를 추가하고, watch preview에서 exercise library의 input type을 canonical ID 기준으로 조회해 전달한다.
2. **Recent dedup 기준 정렬**: compact recent 섹션이 실제로 렌더링하는 set 기반 manual record만 dedup 대상으로 사용한다.
3. **색상 asset 로딩 안정화**: shared colorset에서 첫 color entry를 universal 기본값으로 정규화해 watch asset catalog 로딩 누락을 제거한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 운동 ID stem 매칭만 강화 | 변경 범위 작음 | inputType 신뢰도를 활용하지 못해 오탐 잔존 | 미채택 |
| Recent dedup 자체 제거 | 누락 위험 최소화 | 중복 표기 증가, 기존 dedup 목적 훼손 | 미채택 |
| watch 전용 colorset 재도입 | 빠른 우회 가능 | iOS/watch 동기화 리스크 재발 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Domain/Models/WorkoutActivityType.swift | modify | distance-based resolve에 inputType guard 추가 |
| DUNEWatch/Views/WorkoutPreviewView.swift | modify | watch exercise library inputType 조회 + resolveDistanceBased 확장 호출 |
| DUNE/Presentation/Activity/Components/ExerciseListSection.swift | modify | compact recent 전용 dedup 대상 함수 추가 |
| DUNETests/CardioWorkoutModeTests.swift | modify | inputType guard/허용 케이스 테스트 추가 |
| DUNETests/ExerciseViewModelTests.swift | modify | recent dedup 대상 필터링 회귀 테스트 추가 |
| Shared/Resources/Colors.xcassets/*Forest*/Contents.json | modify | 첫 color entry를 universal 기본값으로 정규화 |
| Shared/Resources/Colors.xcassets/*Ocean*/Contents.json | modify | 첫 color entry를 universal 기본값으로 정규화 |

## Implementation Steps

### Step 1: Watch cardio 분기 오탐 제거

- **Files**: `WorkoutActivityType.swift`, `WorkoutPreviewView.swift`
- **Changes**:
  - `resolveDistanceBased(from:name:inputTypeRaw:)` 시그니처 확장
  - 비카디오 input type(`durationDistance` 외) 조기 반환
  - watch connectivity library를 canonical ID 기준으로 조회해 input type 전달
- **Verification**:
  - `CardioWorkoutModeTests` 신규 케이스 통과

### Step 2: Recent dedup 범위 보정

- **Files**: `ExerciseListSection.swift`
- **Changes**:
  - `recentListDedupRecords(from:)` 헬퍼 추가
  - compact list dedup을 set 기반 manual record로 한정
- **Verification**:
  - watch 러닝 HK summary가 no-set manual record에 의해 숨겨지지 않는 테스트 통과

### Step 3: Shared colorset watch 로딩 안정화

- **Files**: `Shared/Resources/Colors.xcassets/*/Contents.json`
- **Changes**:
  - light appearance-only 첫 항목을 universal 항목으로 정규화
- **Verification**:
  - watch 빌드 산출물 `Assets.car`에 Forest/Ocean theme 색상 존재 확인
  - watch runtime color missing 로그 재현 실패(해결)

## Edge Cases

| Case | Handling |
|------|----------|
| `walking-lunge` 같이 stem이 cardio와 겹치는 비카디오 운동 | inputType guard로 분기 차단 |
| manual record는 있으나 set이 없는 상태의 cardio 기록 | compact list dedup 대상 제외로 HK 표시 보존 |
| dark mode variant만 남는 colorset 정의 | universal 기본값 보장으로 watch lookup 안정화 |

## Testing Strategy

- Unit tests:
  - `DUNETests/CardioWorkoutModeTests`
  - `DUNETests/ExerciseViewModelTests`
- Integration tests:
  - `xcodebuild test -scheme DUNETests -only-testing:...`
  - `xcodebuild build -scheme DUNEWatch`
- Manual verification:
  - watch에서 단일 걷기/근력 프리뷰 시작 버튼 플로우 확인
  - Activity > Recent Workouts에 watch 러닝 노출 확인
  - 콘솔에 `No color named 'ForestAccent'` 재발 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| inputType 데이터 누락 운동에서 분기 변화 | low | medium | inputType nil일 때 기존 3-step fallback 유지 |
| dedup 범위 축소로 중복 노출 증가 | low | low | compact list 렌더링 대상과 dedup 대상 정합 유지 |
| 대량 colorset JSON 수정 중 오타 | medium | medium | watch build + Assets.car 이름 검증 수행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 세 문제의 원인이 독립적으로 확인되었고, 단위 테스트/타깃 빌드/asset 존재 검증으로 수정 유효성을 확인했다.
