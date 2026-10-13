---
topic: Today 탭 최상단 스크롤 바운스 수정
date: 2026-10-13
category: plan
status: draft
confidence: medium
tags: [today, swiftui, scrollview, lazyvgrid, swiftdata, ui-test]
related_solutions:
  - docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md
  - docs/solutions/performance/2026-03-29-observation-tracking-feedback-loop.md
related_brainstorms:
  - docs/brainstorms/2026-03-13-dashboard-smooth-transitions.md
---

# Implementation Plan: Today 탭 최상단 스크롤 바운스 수정

## Context

사용자 영상에서 Today 탭을 위로 스크롤하는 동안 첫 카드와 내비게이션 제목이 반복해서 흔들리고 최상단에 안정적으로 안착하지 못한다. 현재 `DashboardView`는 하나의 스크롤 화면에 `@Query` 두 개와 `LazyVGrid` 카드 그리드를 함께 둔다. 같은 조합에서 Wellness 탭의 무한 바운스를 해결한 기록이 있다. 영상만으로 단일 원인을 확정할 수 없으므로 seeded UI 재현과 수정 전후 위치 측정으로 확인한다.

## Requirements

### Functional

- Today 탭에서 아래로 스크롤한 뒤 위로 드래그하면 첫 카드가 정상 최상단 위치로 돌아온다.
- 상단에서 연속 드래그해도 카드 위치가 반복해서 튀거나 스크롤이 잠기지 않는다.
- 탭 재선택으로 최상단에 이동하는 기존 동작과 카드 진입이 유지된다.

### Non-functional

- 카드 수가 적은 현재 화면에 맞춰 레이아웃 높이를 안정적으로 유지한다.
- 기존 카드 식별자, 메뉴, 애니메이션 순서와 두 열 배치를 보존한다.
- 다른 탭 및 HealthKit/SwiftData 데이터 계약을 변경하지 않는다.

## Approach

우선 Today 카드 그리드를 기존 Wellness 해결책과 같은 eager 2열 레이아웃으로 바꾸고, 스크롤 뷰의 바운스를 콘텐츠 크기에 맞춘다. 이는 SwiftUI가 스크롤 중 셀을 생성·제거하며 콘텐츠 높이를 다시 계산할 가능성을 제거한다. Apple 문서도 `LazyVGrid`를 큰 스크롤 컬렉션에 쓰고 일반 그리드는 자식 뷰를 즉시 생성한다고 설명한다. 수정 후 seeded UI 테스트에서 상단 복귀 및 위치 안정성을 확인한다. 재현이 계속되면 `@Query` 관찰 범위를 자식 뷰로 격리하는 방향을 추가 조사한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `LazyVGrid` 유지, bounce만 조정 | 변경량 작음 | 과거 동일 증상에서 근본 해결에 실패 | 단독 적용하지 않음 |
| `@Query` 두 개를 즉시 자식으로 분리 | 부모 갱신 감소 | 데이터 사용 경로가 넓어 변경 범위 증가 | eager 레이아웃 후 필요할 때 적용 |
| eager 2열 + `.basedOnSize` | 작은 카드 집합에 적합, 높이 안정화 | 모든 카드 즉시 생성 | 우선 적용 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 수정 | 카드 그리드 eager 2열 전환 및 스크롤 바운스 설정 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 수정 | seeded 데이터에서 수동 상단 드래그와 위치 안정성 회귀 테스트 |
| `docs/solutions/performance/2026-10-13-today-scroll-top-bounce.md` | 추가 | 최종 확인된 원인, 해결 및 예방 기록 |

## Implementation Steps

### Step 1: 재현 기준 고정

- **Files**: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
- **Changes**: 첫 카드의 초기 frame을 기준으로 아래로 스크롤했다가 위로 복귀시키고, 멈춘 뒤 위치와 인터랙션을 확인하는 테스트 추가
- **Verification**: seeded UI 테스트를 수정 전 실행하여 재현 여부와 시뮬레이터 한계를 기록

### Step 2: 안정적인 카드 레이아웃 적용

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`
- **Changes**: `LazyVGrid`를 eager `VStack`/`HStack` 두 열로 교체하고 카드별 modifier를 공유해 기능을 보존; `.scrollBounceBehavior(.basedOnSize)` 설정
- **Verification**: iOS 빌드와 Today UI 테스트로 상단 복귀, 카드 탭 및 기존 탭 재선택 확인

### Step 3: 최종 검증 및 문서화

- **Files**: 관련 테스트 및 solution 문서
- **Changes**: 영상과 동일한 스크롤 흐름을 seeded UI에서 확인하고 최종 구현 기준으로 해결책 기록
- **Verification**: 관련 UI suite 결과, `scripts/build-ios.sh`, 리뷰 findings

## Edge Cases

| Case | Handling |
|------|----------|
| 카드 수가 홀수 | 마지막 행의 빈 칸을 같은 너비로 유지 |
| 카드가 0개 | 빈 그리드를 렌더링하지 않음 |
| iPad regular width | 기존 두 열 및 inspector 진입 보존 |
| 초기 데이터 로딩 중 레이아웃 변화 | 기존 skeleton과 등장 애니메이션 유지, 로딩 완료 뒤 상단 위치 검증 |
| pull-to-refresh | 기존 `.waveRefreshable` 유지, 복귀 후 별도 제스처 충돌 확인 |

## Testing Strategy

- Unit tests: 순수 비즈니스 로직 변경이 없어 추가하지 않음.
- UI tests: `TodaySettingsRegressionTests`에 seeded 상단 복귀 테스트를 추가하고 기존 재선택/카드 진입 테스트와 함께 실행.
- Manual verification: 영상의 Today 탭처럼 중간 위치에서 짧은 위쪽 드래그를 반복해 제목과 첫 카드가 흔들리지 않고 최상단에 안착하는지 확인.
- UI 범위: `scripts/plan-ui-tests.py --base main` 결과와 실제 소비자를 대조해 관련 Today suite 및 공통 smoke를 선택.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| eager 생성으로 초기 렌더 비용 증가 | 낮음 | 중간 | 현재 카드 수 확인, UI 테스트와 빌드 후 성능 관점 리뷰 |
| 카드 행 높이/간격 변화 | 중간 | 중간 | 기존 `GridItem` 간격과 동일한 spacing 사용, iPhone/iPad 화면 확인 |
| 영상의 실제 원인이 별도 비동기 갱신 | 중간 | 높음 | 수정 전후 UI 결과 비교; 남으면 `@Query`·refresh 트리거 격리 조사 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 동일 저장소에서 같은 `@Query` + lazy grid 조합의 바운스 해결 이력이 있지만, 첨부 영상만으로 내부 갱신 시점을 확인할 수 없다.
