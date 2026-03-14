---
topic: Dashboard small-phone ellipsis check
date: 2026-03-15
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-08-notification-hub-summary-inline-navigation-link-wrap.md
related_brainstorms:
  - docs/brainstorms/2026-02-16-dashboard-ux-redesign.md
---

# Implementation Plan: Dashboard small-phone ellipsis check

## Context

Today 화면의 작은 폰 폭(iPhone 17)에서 카드 값이 `...`로 말줄임 되는지, 아니면 이미 방어 로직으로 해결된 상태인지 확인해야 한다. 스크린샷상 Activity 섹션의 걸음 수 카드가 가장 유력한 후보이며, `VitalCard`가 Today 카드 전반에 공통 사용된다.

## Requirements

### Functional

- iPhone 17 기준으로 Today 화면 seed 데이터 상태를 실제로 확인한다.
- 말줄임이 재현되면 원인을 특정한다.
- 재현 시 최소 범위 수정과 회귀 방지 테스트를 추가한다.
- 재현되지 않으면 현재 코드가 왜 안전한지 근거를 남긴다.

### Non-functional

- 기존 Today 카드 레이아웃과 시각적 계층을 유지한다.
- 접근성/현지화 문자열이 폭 축소 시에도 불필요한 잘림을 만들지 않도록 본다.
- 변경이 필요 없으면 코드 churn을 만들지 않는다.

## Approach

코드 조사로 Today 카드의 폭 제약과 값 포맷 경로를 먼저 확인한 뒤, iPhone 17 simulator에서 seed mock 데이터로 실제 화면을 캡처해 검증한다. 재현이 확인될 때만 `VitalCard` 또는 값 포맷 경로를 최소 수정하고, UI 테스트에 회귀 검증을 추가한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 코드 정적 분석만으로 판단 | 빠름 | 실제 기기 폭/폰트 렌더링 차이를 놓칠 수 있음 | 기각 |
| 바로 레이아웃 수정 | 즉시 완화 가능 | 이미 해결된 경우 불필요한 churn 발생 | 기각 |
| 코드 조사 + simulator 실검증 + 조건부 수정 | 실제 증빙 확보, 변경 최소화 | 빌드/테스트 시간이 듦 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | inspect / maybe update | Today 카드 2열 그리드 폭 확인 |
| `DUNE/Presentation/Wellness/Components/VitalCard.swift` | inspect / maybe update | 카드 값 텍스트 축소/말줄임 동작 확인 |
| `DUNE/Presentation/Shared/Extensions/HealthMetric+View.swift` | inspect / maybe update | 숫자/단위 포맷 길이 확인 |
| `DUNE/App/TestDataSeeder.swift` | inspect | seed 데이터 값 범위 확인 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` or nearby UI tests | maybe update | 재현 시 작은 폰 회귀 검증 추가 |

## Implementation Steps

### Step 1: Investigate current layout path

- **Files**: `DashboardView.swift`, `VitalCard.swift`, `HealthMetric+View.swift`, `TestDataSeeder.swift`
- **Changes**: no-op 조사; 카드 폭, 텍스트 modifier, seed 값 길이 파악
- **Verification**: 관련 심볼/코드 경로와 재현 가능 조건 정리

### Step 2: Validate on iPhone 17

- **Files**: none or UI test artifacts only
- **Changes**: iPhone 17 simulator에서 `--uitesting --seed-mock`으로 Today 화면 실행 후 스크린샷/테스트로 확인
- **Verification**: Today 화면에서 후보 카드의 말줄임 여부 확인

### Step 3: Apply minimum fix only if needed

- **Files**: `VitalCard.swift`, optional UI test file
- **Changes**: 필요 시 값/단위 레이아웃 또는 grid 대응 최소 수정, 회귀 테스트 추가
- **Verification**: iPhone 17에서 말줄임 해소, 기존 smoke/build 통과

## Edge Cases

| Case | Handling |
|------|----------|
| seed 데이터는 안전하지만 실제 데이터가 더 길 수 있음 | 현재 포맷 최대 길이와 단위 조합까지 코드로 함께 점검 |
| 숫자 자체는 맞지만 unit/change badge가 폭을 과하게 점유 | 값/단위/변화 indicator의 우선순위와 축소 동작을 같이 확인 |
| detached HEAD라 ship 불가 | 검증/수정은 진행하되 ship 단계는 차단 사유를 명시 |

## Testing Strategy

- Unit tests: 포맷 로직 수정이 생길 때만 관련 테스트 검토
- Integration tests: `xcodebuild test`로 iPhone 17 대상 Dashboard 관련 UI 테스트 실행
- Manual verification: iPhone 17 simulator screenshot으로 Today 화면 직접 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| simulator와 사용자 스크린샷 조건 차이 | medium | medium | seed mock + 동일 기종(iPhone 17)으로 검증 |
| 한 카드만 고치고 다른 metric에서 회귀 | medium | medium | 공통 `VitalCard` 경로와 여러 metric 표시를 같이 확인 |
| 불필요한 UI 수정 | medium | low | 재현 확인 전에는 코드 수정 금지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 공통 카드 경로와 seed 기반 검증 경로는 확인됐지만, 실제 말줄임 여부는 simulator 렌더링으로 최종 확인이 필요하다.
