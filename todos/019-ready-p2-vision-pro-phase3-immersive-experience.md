---
source: brainstorm/vision-pro-features
priority: p2
status: ready
created: 2026-03-05
updated: 2026-03-05
---

# Vision Pro Phase 3: Immersive Space 경험

## 목표
ImmersiveSpace를 활용한 몰입형 건강/회복 경험 구현.

## 범위

### Condition Atmosphere (C1 — Progressive)
- 컨디션 점수에 따라 주변 환경 분위기 변경
  - 90+: 맑은 하늘, 따뜻한 빛
  - 70-89: 약간 흐린 하늘
  - 50-69: 안개 낀 환경
  - <50: 어두운 구름
- DUNE desert 테마와 연계

### Mindful Recovery Session (C2 — Full)
- 컨디션이 낮을 때 회복 세션 제안
- Vision Pro 호흡 추적 + 파티클 피드백
- 세션 완료 후 HealthKit mindful minutes 기록

### Sleep Journey (C4 — Progressive)
- 수면 데이터를 시간순 공간 여행으로 체험
- 수면 단계별 환경 변화 (Awake→Core→Deep→REM)

## 기술 요구사항
- ImmersiveSpace (progressive, full)
- Skybox 환경 전환
- 파티클 시스템 (호흡 피드백)
- 호흡 감지 API (visionOS camera/sensor)

## 참고
- `docs/brainstorms/2026-03-05-vision-pro-features.md` Category C
- Apple Mindfulness 앱 참고
