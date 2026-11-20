---
tags: [watchos, accessibility, workout]
date: 2026-11-21
category: design
---
# 야외 운동 고도와 누적 상승

유효한 GPS 표본으로 최근 고도와 누적 상승을 보여 준다. 수직 정확도 20m 이내 표본을 쓰고 3m 미만의 흔들림을 누적 상승에서 걸러 낸다.

Workout 화면의 직접 실행 경로에서 페이지 식별자를 확인한 뒤 해당 상태를 검증했다. 페이지 상위 식별자가 하위 지표의 VoiceOver 값을 덮지 않도록 읽기 단위를 명시했다.

통합 실행에서 Watch 단위 테스트 23건, 심박·고도 UI 5건이 통과했다. 이 기능의 화면·테스트명·원본 해시는 [실제 화면맵](../../design/phone-design-map/actual/watch-outdoor-elevation-2026-11-21/index.html)에 보존했다.
