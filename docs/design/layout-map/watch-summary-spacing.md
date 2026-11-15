---
tags: [watchos, layout, workout-summary, spacing]
date: 2026-11-04
category: plan
status: implemented
---

# Watch 운동 요약 하단 간격

`SessionSummaryView`의 F01·F02·F03·F05·F06·F07은 요약 내용 → 12pt 간격 → 하단 고정 완료/재시도 버튼 순서다. `safeAreaInset`의 spacing에 Watch `DS.Spacing.lg`를 적용해 맨 아래까지 스크롤해도 마지막 운동 내역이나 운동 강도 카드와 버튼 사이를 구분한다. 버튼의 기존 높이·가로 여백·저장 동작은 유지한다.

영향 플랫폼은 Watch뿐이다. 일반 iPhone·iPad·Duo는 이 View를 사용하지 않는다. 테마 색·배경은 [테마 맵](../theme-map/index.html)의 기존 기준을 유지한다. 실제 캡처 상태와 출처는 [Watch 실제 화면 맵](../phone-design-map/actual/watch/index.html)에서 별도로 추적한다.

2026-11-15 완료·복귀 상태 계약: 저장된 요약의 하단 완료를 누르면 홈으로 돌아가며, 백그라운드 복귀와 앱 재실행 뒤에도 닫은 요약이나 저장 오류를 다시 열지 않는다. 닫지 않은 운동의 복구는 유지한다. 운동 강도 시트의 완료는 시트만 닫는 별도 동작이다. 배치·문구·테마 기준은 변경하지 않았다. 관련 검증과 실기기 복구의 한계는 [운동 복구 해결책](../../solutions/general/2026-11-15-watch-workout-recovery-identity.md)을 따른다.
