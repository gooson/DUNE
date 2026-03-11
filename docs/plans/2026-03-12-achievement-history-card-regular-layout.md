---
topic: achievement-history-card-regular-layout
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-activity-section-consolidation.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
related_brainstorms: []
---

# Implementation Plan: Achievement History Card Regular Layout

## Context

Activity 탭의 `Achievement History` 섹션이 iPad/macOS의 regular width 환경에서 다른 카드 대비 지나치게 좁게 렌더링된다. 특히 empty state에서는 카드가 intrinsic content width에 맞춰 축소되어, 넓은 섹션 안에 작은 카드가 떠 있는 것처럼 보인다.

## Requirements

### Functional

- `Achievement History` preview card가 regular width 환경에서 섹션 폭을 자연스럽게 사용해야 한다.
- populated state와 empty state 모두 시각적으로 충분한 카드 크기를 유지해야 한다.
- 기존 navigation 동작과 localized string 동작은 유지해야 한다.

### Non-functional

- 변경 범위는 Activity 탭 preview UI에 한정한다.
- 기존 `SectionGroup`/`StandardCard` 패턴을 재사용한다.
- iPhone compact layout은 불필요하게 흔들지 않는다.

## Approach

`AchievementHistoryPreview` 내부에서 card content를 full-width로 확장하고, regular size class에서 preview density와 spacing을 소폭 키운다. 이렇게 하면 공용 `SectionGroup`을 건드리지 않고 문제 섹션만 안정적으로 보정할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `AchievementHistoryPreview`에 full-width/min-height 부여 | 영향 범위가 작고 원인과 직접 맞닿음 | preview 전용 분기 필요 | 선택 |
| `SectionGroup` 자체를 강제로 full-width child 레이아웃으로 변경 | 전체 섹션 공통 개선 가능 | 다른 섹션의 의도된 intrinsic 레이아웃까지 흔들 수 있음 | 미선택 |
| Activity regular 레이아웃에서 Achievement/Consistency를 2열 재배치 | 시각적 균형 개선 가능 | 구조 변경 폭이 크고 현재 버그보다 범위가 큼 | 미선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | `AchievementHistoryPreview`의 regular-width sizing과 preview density 조정 |

## Implementation Steps

### Step 1: Diagnose preview sizing root cause

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Activity/Components/PersonalRecordsSection.swift`, `DUNE/Presentation/Activity/Components/ConsistencyCard.swift`
- **Changes**: 폭을 채우는 카드와 `AchievementHistoryPreview`의 차이를 비교해 sizing 원인을 확정한다.
- **Verification**: `AchievementHistoryPreview`에 `.frame(maxWidth: .infinity, alignment: .leading)`가 빠져 있는지 확인한다.

### Step 2: Expand regular-width achievement preview

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**: preview card content를 full-width로 확장하고, regular size class에서 padding/min height/preview count를 조정한다.
- **Verification**: 코드상 empty/populated state 모두 full-width가 보장되는지 확인한다.

### Step 3: Validate UI regression surface

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**: navigation link wrapping, localization, compact layout fallback이 유지되는지 점검한다.
- **Verification**: `scripts/build-ios.sh` 및 관련 Activity UI 테스트/수동 확인 항목으로 검증한다.

## Edge Cases

| Case | Handling |
|------|----------|
| reward history가 비어 있는 경우 | empty state를 full-width + regular min-height로 렌더링 |
| reward history가 많은 경우 | regular에서 preview count를 소폭 늘리되 detail navigation으로 전체 접근 유지 |
| iPhone compact layout | 기존 3개 preview와 compact spacing을 유지 |

## Testing Strategy

- Unit tests: 없음. SwiftUI preview/layout 변경으로 로직 테스트 대상이 아니다.
- Integration tests: 필요 시 `scripts/test-ui.sh --smoke` 또는 Activity smoke suite로 화면 진입 회귀 확인.
- Manual verification: iPad/macOS regular width에서 Activity 탭의 `Achievement History` empty/populated state를 확인한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| regular 전용 min-height가 과하게 커 보일 수 있음 | medium | low | compact와 regular를 분리하고 최소한의 높이만 부여 |
| preview count 증가로 card height가 과도해질 수 있음 | low | low | regular에서만 1개 증가 수준으로 제한 |
| 현재 worktree가 detached HEAD 상태 | high | medium | ship 단계에서 브랜치 상태를 명시적으로 보고하고, 자동 PR/merge는 가능 여부를 확인 후 진행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 문제 원인이 `AchievementHistoryPreview`의 intrinsic sizing으로 명확하게 드러나고, 기존 full-width 카드 패턴도 동일 파일군에서 확인되었다.
