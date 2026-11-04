---
tags: [watchos, layout, workout-summary, spacing]
date: 2026-11-04
category: plan
status: implemented
---

# Watch 운동 요약 하단 간격

`SessionSummaryView`의 F01·F02·F03·F05·F06·F07은 요약 내용 → 12pt 간격 → 하단 고정 완료/재시도 버튼 순서다. `safeAreaInset`의 spacing에 Watch `DS.Spacing.lg`를 적용해 맨 아래까지 스크롤해도 마지막 운동 내역이나 운동 강도 카드와 버튼 사이를 구분한다. 버튼의 기존 높이·가로 여백·저장 동작은 유지한다.

영향 플랫폼은 Watch뿐이다. 일반 iPhone·iPad·Duo는 이 View를 사용하지 않는다. 테마 색·배경은 [테마 맵](../theme-map/index.html)의 기존 기준을 유지한다. 실제 캡처 상태와 출처는 [Watch 실제 화면 맵](../phone-design-map/actual/watch/index.html)에서 별도로 추적한다.
