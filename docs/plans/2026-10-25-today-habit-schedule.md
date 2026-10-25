---
topic: today-habit-schedule
tags: [life, habits, schedule]
date: 2026-10-25
category: plan
status: approved
confidence: high
related_solutions: [2026-04-05-habit-early-completion-fix]
---

# 오늘의 습관 대상 분리

## Context

오늘 히어로가 모든 수동 활성 습관을 분모로 사용해 주간 목표·미래 반복 일정까지 매일 할 일처럼 표시한다. 기존 Today/Watch 변경이 없는 origin/main의 전용 worktree에서 수정한다.

## Requirements / Approach

- Today: daily + due/overdue interval + today-completed interval. Weekly는 날짜가 지정되지 않은 주간 목표이므로 오늘 분모에서 제외한다.
- Weekly: weekly 습관. Upcoming: 나머지 interval (미래 시작·첫 완료 대기 포함). 모든 항목의 기존 편집·기록·이력 경로를 유지한다.
- interval 완료는 referenceDate와 같은 날에 실제 완료했을 때만 true. 조기 완료·당일 중복 방지 계약을 유지한다.
- 오늘 대상이 없고 활성 습관이 있는 경우 새 습관 추가 안내 대신 오늘 예정 없음 안내.
- 저장 스키마·알림·역사 통계는 변경하지 않는다.

## Affected Files

| File | Change Type | Description |
|---|---|---|
| DUNE/Presentation/Life/LifeViewModel.swift | 수정 | 일정별 캐시 배열과 오늘 집계 |
| DUNE/Presentation/Life/LifeView.swift | 수정 | 오늘·주간·다가오는 항목별 표시 |
| DUNETests/LifeViewModelTests.swift | 수정 | 일정 경계·분모·조기 완료 회귀 |
| DUNEUITests/Full/LifeRegressionTests.swift | 수정 | 실제 생성 흐름으로 주간·반복 분리 검증 |
| Shared/Resources/Localizable.xcstrings | 수정 | en/ko/ja 안내·그룹 제목 |
| docs/design/layout-map/index.html | 수정 | L01 정보 순서·집계 계약 |
| docs/design/phone-design-map/** | 수정 | L01 최신 캡처·출처 또는 차단 사유 |

## Implementation Steps

1. VM 분류와 테스트를 먼저 구현한다. daily/weekly/interval, due/overdue, 완료 전후/다음날, archived/auto-linked, 첫 완료 대기와 미래 시작을 검증한다.
2. 기존 My Habits 내부에 Today→Weekly→Upcoming을 배치한다. 시간대·카테고리 필터와 액션은 유지한다. 문자열을 번역하고 catalog를 포맷한다.
3. 관련 단위·Life UI 테스트와 iOS 빌드를 확인한다. 전체 테스트로 확대하지 않는다. iPhone/iPad/Duo L01 캡처는 전용 기기로만 실행하며 환경 차단 시 화면과 원인을 명시한다.
4. review-ship: base 대비 전체 변경을 read-only 리뷰, findings 보고, Resolve, 검증 후 PR 생성·원격 merge·소유 리소스 정리.

## Edge Cases

- interval 완료 직후 예정일이 미래로 이동하더라도 당일 Today에서 사라지지 않는다.
- 이전 날짜의 완료는 다음 날 Today의 분자에 포함하지 않는다.
- weekly 목표 7일도 weekly 그룹에 유지한다. 실제 실행일을 임의 추정하지 않는다.
- 전체 습관 없음과 오늘 대상 없음의 문구를 구분한다.
- snooze/skip 후 예정일 이동과 첫 완료 시작 방식은 기존 동작을 유지한다.

## Testing Strategy / Risks

날짜를 고정한 VM 테스트와 폼 생성 UI 테스트로 집계와 표시를 검증한다. 위험은 기존 통계와 당일 집계의 혼동이며 historical trend는 실제 기록 수라는 기존 라벨을 유지한다. 시뮬레이터·잠금 차단 시 동일 원인 무변화 재시도 없이 증거를 남긴다.
