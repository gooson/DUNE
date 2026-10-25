---
topic: activity-life-hero-rhythm
date: 2026-10-25
status: approved
confidence: high
related_solutions: [2026-10-17-honest-hero-trends-and-capture, 2026-10-22-contextual-first-fold-hero]
related_brainstorms: [2026-03-07-activity-tab-hero-first-layout, 2026-03-22-life-tab-enhancement]
---

# Implementation Plan: Activity·Life 히어로 흐름과 근거

## Context

사용자가 두 히어로의 정보 밀도를 개선하는 `흐름과 근거` 시안을 승인하고 `/run` 구현·검증·리뷰·머지를 요청했다. 기존 Today·Watch 변경을 포함하지 않도록 main 기준 전용 worktree와 feature/activity-life-hero-rhythm 브랜치를 사용한다.

## Requirements

- A01은 기존 124pt 링·상태·준비도 상세 목적지를 유지하고 HRV·수면·회복 구성 점수, 저장된 준비도의 7일 흐름을 추가한다.
- L01은 기존 124pt 완료/대상 링·상태·체크리스트 목적지를 유지하고 완료·대상·남음 요약 및 현재 수동 습관의 최근 7일 완료 기록을 추가한다. 개별 습관을 히어로에 중복 나열하지 않는다.
- en/ko/ja, 밝음·어두움, 접근성 글씨, iPhone·iPad·Duo 접힘·펼침에 대응한다. Watch는 소비하지 않아 제외한다.
- 임의 점수·가짜 과거 분모를 표시하지 않는다. 앱 기존 점수 계산과 습관 완료 의미를 바꾸지 않는다.

## Approach

Activity의 기존 ScoreRefreshService.fetchRollingSnapshots를 통해 8일 범위의 저장된 readinessScore를 읽고, 각 날짜의 가장 최근 유효값을 사용한다. 오늘 값은 현재 링 점수로 맞춘다. 7일은 oldest-first이며 nil 날짜를 보간/0점 처리하지 않는다. 상세의 과거 approximate readiness 계산은 히어로로 재사용하지 않는다.

Life는 기존 HabitAnalyticsService.dailyCompletionCounts의 기록 집계를 재사용하되 auto-linked 습관을 제외하고 오늘 막대는 실제 오늘 완료 기록 개수로 유지한다. 현재 링은 주기형 습관의 현재 상태도 포함할 수 있으므로 `오늘의 진행`과 `일별 완료 기록`을 다른 의미로 명시한다. 생성 이전 날짜는 기록 없음으로 표시한다. 과거 대상 수는 저장되어 있지 않아 예시 시안의 /6을 실제 앱에서 재현하지 않는다.

두 기능은 작은 공통 막대 뷰와 SwiftData-free 일별 점수 변환을 재사용한다. 표본 0·1개는 추세가 아닌 데이터 대기 안내로 표시한다. 기본 글씨는 7열 막대, 큰 글씨는 줄바꿈 가능한 날짜·값 목록으로 전환한다. 별도 제스처를 추가하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 상세의 근사 준비도 재계산 | 기존 HealthKit 배열 재사용 | 현재 점수와 산식 다름 | 제외 |
| 매일 고정 습관 분모 | 시안 그대로 표현 | 변경·주기형 습관의 과거 의미를 만들게 됨 | 제외 |
| 저장된 준비도·실제 완료 기록 | 관측 근거와 결측 명확 | 처음에는 빈 기록이 많음 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| Activity/ActivityView.swift, ActivityViewModel.swift | edit | 구성 점수·기록 추세 연결 |
| Presentation/Activity/Components/*Hero*.swift | edit/add | 준비도 히어로 표현 |
| Presentation/Life/LifeView.swift | edit | 요약·완료 기록 추가 |
| Presentation/Shared/Components/WeeklyHeroTrendView.swift | add | 공통 막대·접근성 목록 |
| Presentation/Shared/Models/WeeklyHeroTrendPoint.swift | add | 순수 날짜별 변환 |
| DUNETests/WeeklyHeroTrendPointTests.swift | add | 정렬·nil·범위·오늘 일치 |
| DUNEUITests/Visual/HeroRhythmUITests.swift, UI fixture | add/edit | seeded 화면·목적지·캡처 |
| Shared/Resources/Localizable.xcstrings | edit | en/ko/ja |
| docs/design/layout-map, theme-map, phone-design-map | edit/add | 계약·시안·새 실제 캡처 |
| docs/solutions/general, docs/reviews | add | 최종 구현·증빙 |

## Implementation Steps

1. 승인 시안 보존본·레이아웃 계약을 연결하고 계획서를 저장한다. `ls`, map check로 검증한다.
2. 공통 일별 점수 모델·막대 뷰와 테스트를 추가한다. Activity 준비도 이력을 캐시하고 구성 점수/상세 행동을 연결한다. 단위별 커밋한다.
3. Life 완료·대상·남음 및 일별 완료 기록을 연결한다. 기존 체크리스트 행동과 현재 진행 계산은 유지한다. 단위별 커밋한다.
4. 번역·접근성 ID·UI 시나리오를 보강하고 표준 빌드 및 관련 단위 테스트를 실행한다.
5. 변경 UI 계획을 재생성하고 관련 iPhone UI+공통 smoke를 실행한다. 실제 캡처는 영향받는 A01/L01만 기기·밝음/어두움·큰 글씨·누락 상태 기준으로 확보한다. 전용 기기를 사용하고 UI 실행은 직렬화한다.
6. diff 기반 5관점 리뷰 및 SwiftUI·Apple UX·UI 테스트·종합 게이트를 수행한다. 수정 시 영향 delta만 재검증한다.
7. solution·최종 검증 보고서를 저장하고 Pre-Ship 확인 후 PR 생성·머지·전용 시뮬레이터 및 worktree 정리를 수행한다.

## Edge Cases

| Case | Handling |
|---|---|
| 서비스 없음·새 사용자·저장값 없음 | 과거는 nil, 충분한 표본이 될 때까지 안내 |
| 같은 날 여러 시각·중복 | 유효 최신 시각 우선, 오늘은 링 값 |
| NaN·Infinity·범위 밖·미래 | 유효 범위 밖 기록 제외 |
| 날짜·DST·자정 | Calendar 날짜 생성, 8일 fetch 후 7일 필터 |
| 수면 구성 데이터 없음 | 준비도의 중립 fallback 점수를 실제 관측처럼 표시하지 않음 |
| 습관 없음·auto-only | 과거 차트/가짜 0/0 숨김 |
| 주기형 습관 | 현재 진행과 일별 완료 기록 의미 분리 |
| 큰 글씨·좁은 가용 폭 | 세로 근거·읽기 가능한 날짜/값 목록, 자연 높이 |

## Testing Strategy

- Unit: 날짜 변환의 7일 정렬, nil, 최신 표본, 미래·NaN·DST·오늘 점수 일치. Life 기록 변환은 재사용 집계 테스트와 신규 경계 테스트.
- Build: scripts/build-ios.sh. xcstrings 전후·빌드 후 format check.
- UI: ui-test-expert가 주요 존재·값·상세·체크리스트·기록 없음과 캡처 시나리오를 추가. scripts/test-ui.sh의 정확한 selector와 전용 simulator 사용.
- 코드 영향 기준 targeted 검증만 실행한다. full 자동 판정은 선택 범위와 이유를 검토하고, 미실행 full은 통과로 보고하지 않는다.
- 실제 캡처: iPhone/iPad/Duo 접힘·펼침 A01/L01, 기본 밝음·어두움과 iPhone 최대 AX. 범위 밖 테마 전수 캡처·Watch·전체 회귀는 실행하지 않는다.
- 동일 실패는 원인에 대응한 변경이 확인된 후 최대 한 번 재시도. 기기/SDK 차단은 미검증으로 기록하고 미완료 게이트를 넘기지 않는다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 준비도 저장 이력 sparse | 높음 | 빈 추세 | 결측 안내와 기록 기준 명시 |
| 현재 습관 상태와 과거 기록 의미 차이 | 중간 | 오독 | 진행·완료 기록 레이블 분리 |
| SDK·Duo 전환·잠금 정체 | 중간 | 캡처 미완료 | 전용 소유권·bounded runner·readback |
| 다른 작업의 기존 변경 혼입 | 높음 | PR 범위 확대 | 독립 main worktree·명시적 파일 staging |

## Confidence Assessment

- Overall: high. 기존 링·목적지·기록 저장 경로를 재사용한다.
- 공식 SwiftUI ViewThatFits/isAccessibilitySize/accessibilityElement 문서를 Context7에서 확인했다. 날짜·집계는 뷰 body 밖에서 계산한다.

## Implementation outcome (2026-10-25)

구현·관련 단위41개·히어로 UI 시나리오·iPhone/iPad/Duo 외부 실제 화면을 완료했다. 정식 리뷰 P1/P2 없음, catalog metadata P3 수정 후 빌드 통과. Today 알림함 두 실패와 Duo 내부 가로 미검증은 사용자 `통과 하고 계속` 승인으로 한계를 보존하고 출시를 진행한다. [해결책](../solutions/architecture/2026-10-25-activity-life-recorded-hero-evidence.md)과 [리뷰](../reviews/2026-10-25-activity-life-hero-review.md)를 참조한다.
