---
tags: [detail-redesign, habits, targeted-ui, l07]
date: 2026-11-06
category: plan
status: done
---

# L07 · 습관 활동 히트맵 상세

## Affected Files

| 파일 | 변경 |
|---|---|
| `DUNE/Presentation/Life/HabitHeatmapDetailView.swift` | 원래 상태·계산·아이콘에서 시각 위계를 보강한다. |
| `DUNEUITests/Full/LifeRegressionTests.swift` | `testVisualAuditHabitHeatmap`와 L08에서 도입하는 공유 Analytics MAX 검사로 기간·통계·격자·범례·요일 값과 Back 복귀를 확인한다. |
| `docs/design/layout-map/life-habit-l07.html` | 앱 변경 전에 배치를 보존한다. |
| `docs/design/theme-map/themes/dune-life-habit-l07.html` | 테마 표현 시안이며 실제 캡처와 구분한다. |

## Implementation Steps

1. 공유 [묶음 계획](2026-11-06-detail-redesign-habit-analytics-batch04.md)의 원본 파일 SHA와 호출부·기능·데이터 불변식을 확인한다.
2. 이 화면의 App 변경만 별도 로컬 커밋하고 공통 UI 검사와 관련 소비자를 독립 리뷰한다.
3. 공유 SDK 실행에서 해당 화면 메서드·기기만 채택하고 실제 PNG·AX를 독립 검토한다. 그 후 실제 디자인맵·해결 문서를 갱신해 화면별 PR을 발행한다.

## Testing Strategy and Risks

이 화면은 push 상세이며 Back으로 Life 루트에 복귀한다. iPhone·iPad·Duo 접힘·펼침 기본 글씨와 접힌 Duo MAX에서 90일 기간, 총 완료·평균·최장 연속·활동일, 격자·범례, 요일별 값 및 조건부 차트를 확인한다. MAX에서는 통계 카드를 한 열로 배치하고 긴 내용의 양 끝이 스크롤로 읽히는지 확인한다. 격자와 범례의 detail-only AX prefix는 Life 루트의 기존 식별자를 보존한다. 원래 90일 데이터·집계·비율과 내비게이션은 유지했다. 고정 통합 소스 `83c350b0`에서 이 화면의 5개 메서드·기기 기여와 PNG·AX 22쌍이 통과했다. 전체 묶음의 19개 조합·21개 화면 기여 및 PR·CI 상태는 각각 별도 증거로 기록한다.

## 실제 선택 화면 검증

[L07 PNG·AX·출처](../design/full-redesign-map/review/l07-habit-heatmap-2026-11-06/index.html). PR/CI 상태는 별도 기록을 따른다.
