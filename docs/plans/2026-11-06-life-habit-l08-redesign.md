---
tags: [detail-redesign, habits, targeted-ui, l08]
date: 2026-11-06
category: plan
status: implemented
---

# L08 · 주간 습관 리포트

## Affected Files

| 파일 | 변경 |
|---|---|
| `DUNE/Presentation/Life/WeeklyHabitReportView.swift` | 원래 상태·계산·아이콘에서 시각 위계를 보강한다. |
| `DUNEUITests/Full/LifeRegressionTests.swift` | `testVisualAuditWeeklyReport`와 공유 `testHabitAnalyticsAtMaximumAccessibilitySize`로 주간 수치·비교·순위 목록과 Back 복귀를 확인한다. |
| `docs/design/layout-map/life-habit-l08.html` | 앱 변경 전에 배치를 보존한다. |
| `docs/design/theme-map/themes/dune-life-habit-l08.html` | 테마 표현 시안이며 실제 캡처와 구분한다. |

## Implementation Steps

1. 공유 [묶음 계획](2026-11-06-detail-redesign-habit-analytics-batch04.md)의 원본 파일 SHA와 호출부·기능·데이터 불변식을 확인한다.
2. 이 화면의 App 변경만 별도 로컬 커밋하고 공통 UI 검사와 관련 소비자를 독립 리뷰한다.
3. 공유 SDK 실행에서 해당 화면 메서드·기기만 채택하고 실제 PNG·AX를 독립 검토한다. 그 후 실제 디자인맵·해결 문서를 갱신해 화면별 PR을 발행한다.

## Testing Strategy and Risks

이 화면은 push 리포트이며 Back으로 Life 루트에 복귀한다. iPhone·iPad·Duo 접힘·펼침 기본 글씨와 접힌 Duo MAX에서 주간 기간, 현재 완료율과 완료/목표 수, 이번 주·지난주 수치와 추세, Best Habits·Needs Improvement의 원래 아이콘과 목록을 확인한다. MAX에서는 비교 영역을 한 열로 읽고 각 수치와 제목을 스크롤로 드러낸다. 비율·분자/분모·순위·빈 상태 계산은 원래 코드로 유지했다. 고정 소스 `83c350b0`에서 이 화면의 5개 메서드·기기 기여와 PNG·AX 22쌍이 통과했다. L07과 공유하는 Analytics MAX 한 케이스만 기존 최대 한도 600초를 명시해 388.580초에 통과했고 나머지 기본 한도는 300초다. 전체 묶음 19개 조합·21개 화면 기여와 PR·CI 상태는 별도 기록을 따른다.

## 실제 선택 화면 검증

[L08 PNG·AX·출처](../design/full-redesign-map/review/l08-habit-weekly-report-2026-11-06/index.html). PR/CI 상태는 별도 기록을 따른다.
