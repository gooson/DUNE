---
topic: first-fold-ux-redesign
date: 2026-10-22
status: in-progress
confidence: high
related_solutions: [docs/solutions/design/hero-cta-button-pattern.md]
related_brainstorms: [docs/brainstorms/2026-03-14-hero-card-detail-unification.md]
---

# Implementation Plan: 4탭 첫 화면 UX 개편

## Context

8개 테마의 배경과 4탭 공통 링, Activity의 운동 기록, Wellness의 수면 상세, Life의 습관 진행 설명은 이미 앱에 적용됐다. 현재 Today(T03)의 큰 히어로 버튼은 Activity 또는 Wellness 탭으로 전환하지만, 같은 카드의 본문은 컨디션 상세로 열린다. 두 목적지가 한 카드에서 경쟁한다. 시간별 추세가 없으면 큰 빈 영역이 남고, 실제 7일 기록은 별도 카드에만 있다. Wellness(H01)은 수면 막대의 기간·값 설명과 신체 기록 행동의 위치가 더 명확해질 수 있다.

## Requirements

- Today 히어로의 단일 진입점은 컨디션 상세로 이어진다. 다른 루트 탭 이동은 탭 바가 맡는다.
- 히어로에는 상세 진입을 눈으로 알 수 있는 짧은 표현을 둔다. 카드 전체가 하나의 접근 가능한 링크다.
- 유효한 시간별 표본이 없을 때 실제 일별 기록이 2개 이상이면 7일 추세를 표시한다. 둘 다 부족하면 짧고 사실적인 상태 문구를 표시한다.
- Wellness의 수면 막대는 날짜를 포함한 최근 수면 기록과 유효한 7일 평균을 구분해 표시한다. 미래 수면 예측은 별도 카드에 둔다.
- 신체 기록은 Wellness의 수면 예측 다음에 놓아 현재 상태, 예측, 직접 기록의 정보 순서를 만든다. 데이터가 없는 상태에서도 직접 기록 경로는 유지한다.
- 기존 A01·L01·W06·T04·H02·S01에서 이미 구현한 흐름은 회귀 검증하고, 증거 없는 장식 변경은 하지 않는다.
- 8개 테마에 동일한 정보 구조를 적용하며 Dynamic Type, iPhone·iPad·Duo에서 내용이 잘리지 않는다.

## Approach

T03 레이아웃 맵과 UX 명세의 행동 계약을 먼저 고친다. Today 히어로의 별도 탭 전환 버튼을 제거하고 링크 안에 상세 진입 표현을 둔다. 기존 `recentScores`와 `TrendChartView`를 시간별 차트의 fallback으로 재사용한다. H01은 기존 수면 표본에서 유효값만 요약하고 큰 기록 버튼을 예측 카드 다음으로 이동한다. 테스트는 목적지, 데이터 상태, 화면 접근성을 검증한다. 새 화면 배치를 실제 앱에서 다시 캡처해 맵에 출처와 함께 반영한다.

## Affected Files

| 범위 | 파일 |
|---|---|
| Today | `DUNE/Presentation/Dashboard/Components/DesertHorizonConditionHeroView.swift`, `DashboardView.swift` |
| Wellness | `DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift`, `WellnessView.swift` |
| UI 검증 | `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Visual/ThemeMatrixUITests.swift`, `WaterLiliesThemeTests.swift`, 관련 Wellness 테스트 |
| 설계·증거 | `docs/design/layout-map/`, `docs/design/2026-10-17-ux-visual-spec.md`, `docs/design/full-redesign-map/`, `docs/design/phone-design-map/actual/` |

## Implementation Steps

1. **설계 계약 갱신:** `docs/design/layout-map/index.html`, `README.md`, `docs/design/2026-10-17-ux-visual-spec.md`, `docs/design/full-redesign-map/README.md`의 T03/H01 동선·순서를 실제 결정에 맞춘다.
2. **T03 구현:** `DesertHorizonConditionHeroView.swift`와 `DashboardView.swift`에서 탭 전환 버튼을 제거한다. 상세 링크의 시각적·접근성 목적지를 드러내고, 시간별→7일→수집 상태 순서로 실제 데이터만 표시한다. 기존 별도 주간 카드의 중복은 판단하여 정리한다.
3. **H01 구현:** `WellnessHeroCard.swift`에서 지난밤과 유효 표본의 평균을 구분한다. `WellnessView.swift`의 신체 기록 행동을 예측 뒤로 이동한다. 빈 상태 경로는 유지한다.
4. **검증:** 현재 동선을 전제로 한 UI 테스트를 상세 push와 탭 바 경로로 바꾸고 수면 요약의 데이터 상태를 확인한다. iOS 빌드, 영향 UI 테스트, 실제 T03/H01 캡처와 육안 대조를 실시한다. A01/L01 및 대표 상세·운동·설정은 기존 구현과 시안을 대조해 이번 변경이 없는 이유를 결과에 남긴다.
5. **리뷰·출하:** `/run`의 리뷰, 품질, 해결책 기록, PR/merge 게이트를 따른다. 실제 캡처하지 못한 기기·상태는 완료로 표시하지 않는다.

## Verification

- Today 히어로에서 `condition-score-detail-screen`으로 진입하고, 카드 안에 다른 탭 전환 버튼이 없다.
- 시간별 표본 2개 이상 / 일별 표본 2개 이상 / 둘 다 부족한 상태 각각 기간 또는 수집 상태를 정확히 보여 준다.
- Wellness의 수면 평균은 `minutes > 0`인 실제 표본이 2개 이상일 때만 사용하며 수면 예측과 섞이지 않는다.
- 신체 기록 버튼은 유효·빈·클라우드 대기 상태에서 접근 가능하고 기존 입력 시트를 연다.
- 영향받은 iPhone 화면의 밝음·어두움, 큰 글씨와 가용한 iPad·Duo 배치를 새 빌드로 확인한다.

## Risks

- 수면 표본 배열의 정렬과 0분 의미를 확인한 후 지난밤·평균을 계산한다.
- Today 링크의 하위 요소를 하나의 버튼으로 접근성에 노출하면서 링·추세 설명이 사라지지 않게 한다.
- 기존 디자인맵 캡처의 기기 ID가 작업 기기와 다를 수 있다. 새 캡처의 출처를 별도로 보존하고 구 캡처를 완료 증거로 재사용하지 않는다.
