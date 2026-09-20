---
source: review/workout-input-release-audit
priority: p2
status: ready
created: 2026-09-20
updated: 2026-09-20
---

# 거리·시간·중량 조합 운동 기록

133개 운동 입력 조사에서 Farmers Walk, Trap Bar Carry, Sled Push, Pec Deck Isometric Hold가 기존 inputType로 충분히 표현되지 않았다.

- 거리/시간 + 외부 중량을 기록할 수 있는 입력 모델과 양 플랫폼 UI를 정의한다.
- 레거시 기록의 reps를 거리/초로 임의 재해석하지 않는다.
- 워치/폰 템플릿, 프리필, 히스토리, 볼륨/PR 계산, WatchConnectivity 왕복 회귀를 검증한다.
- 작은 워치/큰 글씨 및 워치↔폰 실제 동기화 검증을 포함한다.

상세 조사: docs/solutions/general/2026-09-20-workout-input-release-audit.md
