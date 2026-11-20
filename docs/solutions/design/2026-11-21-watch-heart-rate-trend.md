---
tags: [watchos, accessibility, workout]
date: 2026-11-21
category: design
---
# 운동 중 최근 30분 심박

최근 30분을 1분 단위로 나누고 HealthKit 측정 시각이 있는 표본만 표시한다. 수신 공백은 그래프의 시간 위치를 유지한다.

Workout 화면의 직접 실행 경로에서 페이지 식별자를 확인한 뒤 해당 상태를 검증했다. 페이지 상위 식별자가 하위 지표의 VoiceOver 값을 덮지 않도록 읽기 단위를 명시했다.

통합 실행에서 Watch 단위 테스트 23건, 심박·고도 UI 5건이 통과했다. 이 기능의 화면·테스트명·원본 해시는 [실제 화면맵](../../design/phone-design-map/actual/watch-heart-rate-trend-2026-11-21/index.html)에 보존했다.
