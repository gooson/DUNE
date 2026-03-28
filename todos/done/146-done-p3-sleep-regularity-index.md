---
source: brainstorm/2026-03-28-sleep-analysis-enhancement
priority: p3
status: done
created: 2026-03-29
updated: 2026-03-29
---

# Sleep Regularity Index (SRI)

## 설명

취침 시간과 기상 시간의 양방향 일관성을 학술 지표(Sleep Regularity Index)로 측정한다.

## 상세

- SRI = 24시간 동안 동일 상태(수면/각성) 확률의 가중 평균
- 기존 `CalculateAverageBedtimeUseCase`의 취침/기상 데이터 재활용
- 최소 7일 데이터 필요, 14일+ 권장
- 100점 = 완벽히 규칙적, 0점 = 완전 불규칙
- Sleep 상세 화면에 "수면 규칙성" 카드로 표시
- 주간 추세 차트 포함

## 선행 조건

- 없음

## 참고

- Phillips et al. (2017) "Irregular sleep/wake patterns are associated with poorer academic performance"
- SRI는 단순 표준편차보다 비연속 수면 패턴을 더 정확히 포착
