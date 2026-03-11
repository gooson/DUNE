---
topic: Watch Set Input RPE Visibility
date: 2026-03-12
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-12-set-rpe-integration.md
  - docs/solutions/general/2026-03-08-watch-crown-focus-host-without-scrollview.md
related_brainstorms:
  - docs/brainstorms/2026-02-28-watch-set-input-previous-data-ux.md
---

# Implementation Plan: Watch Set Input RPE Visibility

## Context

watch strength workout flow에서 RPE 입력이 `MetricsView`의 별도 sheet 뒤로 숨겨져 있다.
사용자는 세트 입력 sheet를 먼저 닫은 뒤 다시 RPE row를 눌러야 해서,
세트 입력 문맥 안에서 RPE를 바로 보거나 수정하기 어렵다.

## Requirements

### Functional

- `SetInputSheet` 진입 시 RPE 입력 진입점이 바로 보여야 한다.
- 기존 per-set RPE 저장 경로(`WorkoutManager.completeSet(weight:reps:rpe:)`)는 유지해야 한다.
- 이전 세트 히스토리, 무게/렙 입력, 세트 완료 flow를 깨뜨리지 않아야 한다.

### Non-functional

- watch crown/slider focus 경고를 다시 만들지 않는다.
- watch workout UI smoke selector를 유지하거나 필요한 경우 명시적으로 확장한다.
- 새 사용자 대면 문자열 추가를 피하고 기존 localized copy를 재사용한다.

## Approach

`SetInputSheet`에 per-set RPE control을 inline으로 노출하고, `MetricsView`의 별도 RPE sheet presenter는 제거한다.
RPE control은 기존 `WatchSetRPEPickerView`를 재사용하되, watch crown host가 무게 입력과 충돌하지 않도록
sheet 내에서는 항상 보이는 collapsed/inline entry 경험을 제공하는 방향으로 배치한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `MetricsView`의 별도 RPE sheet 유지 | 구현 범위가 작음 | 사용자는 세트 입력 sheet를 닫은 뒤 다시 진입해야 해서 "숨김" 체감이 그대로 남음 | Rejected |
| `SetInputSheet` 안에 항상 확장된 RPE slider 표시 | 한 화면에서 모두 조작 가능 | crown host 충돌 위험이 높고 작은 watch에서 세로 밀도가 과해짐 | Rejected |
| `SetInputSheet` 안에 RPE entry를 노출하고 기존 picker를 같은 문맥에서 재사용 | 사용자가 세트 입력 중 바로 RPE 존재를 인지 가능, 현재 저장 경로 재사용 가능 | set input 레이아웃과 AXID를 함께 조정해야 함 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Views/SetInputSheet.swift` | update | RPE 진입 UI를 sheet 본문에 추가하고 parent binding 전달 |
| `DUNEWatch/Views/MetricsView.swift` | update | 별도 RPE sheet presenter 제거, set input으로 RPE binding 전달 |
| `DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift` | update | set input RPE selector 추가 |
| `DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests.swift` | update | 새 selector inventory 반영 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | update | set input RPE selector 노출 |
| `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift` | update | auto-present set input에서 RPE entry 노출 smoke 추가 |
| `docs/solutions/architecture/2026-03-12-set-rpe-integration.md` | update | watch interaction contract를 현재 구현과 일치시킴 |

## Implementation Steps

### Step 1: Set Input Sheet에 RPE entry 복귀

- **Files**: `DUNEWatch/Views/SetInputSheet.swift`
- **Changes**:
  - `@Binding var rpe: Double?`를 추가한다.
  - weight/reps 아래에 RPE control을 노출한다.
  - RPE control은 set input 문맥에서 바로 보이도록 배치하되 기존 previous sets flow는 유지한다.
- **Verification**: sheet auto-present 시 weight/reps와 함께 RPE entry가 보인다.

### Step 2: MetricsView 숨겨진 RPE sheet 경로 정리

- **Files**: `DUNEWatch/Views/MetricsView.swift`
- **Changes**:
  - `showRPESheet` 기반 별도 presenter를 제거한다.
  - `SetInputSheet`로 `rpe` binding을 전달한다.
  - 세트 완료/운동 전환 시 RPE 상태 리셋 동작은 유지한다.
- **Verification**: 기존 complete set, rest timer, next exercise flow가 동일하게 동작한다.

### Step 3: UI contract와 smoke lane 고정

- **Files**: `DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift`, `DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests.swift`, `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`, `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift`
- **Changes**:
  - set input RPE UI용 AXID를 추가한다.
  - auto-present set input smoke에서 해당 selector 존재를 확인한다.
- **Verification**: selector uniqueness test와 smoke test가 새 contract를 반영한다.

### Step 4: 관련 solution 문서 동기화

- **Files**: `docs/solutions/architecture/2026-03-12-set-rpe-integration.md`
- **Changes**:
  - watch layer 설명을 `MetricsView` hidden sheet 기준에서 `SetInputSheet` visible entry 기준으로 갱신한다.
- **Verification**: 문서가 실제 interaction contract와 일치한다.

## Edge Cases

| Case | Handling |
|------|----------|
| RPE 미선택 상태 | 기존 inactive copy(`Tap to rate`)를 그대로 사용 |
| 세트 완료 후 다음 세트 시작 | `MetricsView`의 `rpe = nil` reset 유지 |
| previous sets가 많은 경우 | 기존 toolbar push 방식 유지, inline 히스토리로 되돌리지 않음 |
| 작은 watch 화면에서 높이 부족 | RPE는 항상 collapsed entry를 기본으로 두고, 본문 밀도를 최소화 |

## Testing Strategy

- Unit tests: `WatchWorkoutSurfaceAccessibilityTests` selector uniqueness 갱신
- Integration tests: `WatchWorkoutStartSmokeTests.testStrengthWorkoutShowsInputAndMetricsSurfaces`에서 set input RPE entry 존재 확인
- Manual verification: strength workout 시작 → auto-present set input에서 RPE entry 확인 → 세트 완료 → rest timer skip → 다음 세트에서도 동일 동작 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| set input에 RPE를 다시 넣으면서 화면 밀도 과다 | Medium | Medium | collapsed entry 기본 유지, spacing 최소 변경 |
| crown focus가 RPE control과 충돌 | Medium | High | 기존 separate crown host 패턴을 깨지 않는 구성으로 유지 |
| smoke selector가 비안정적으로 노출 | Low | Medium | dedicated AXID 추가 후 PR smoke에 고정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 구현 범위는 좁지만 watch sheet/crown interaction이 예민해서, visible entry와 crown host를 함께 다뤄야 한다.
