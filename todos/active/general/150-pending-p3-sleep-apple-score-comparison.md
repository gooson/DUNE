---
source: brainstorm/2026-03-28-sleep-analysis-enhancement
priority: p3
status: pending
created: 2026-03-29
updated: 2026-03-29
---

# Apple Sleep Score 비교

## 설명

watchOS 26의 Apple Sleep Score와 DUNE Sleep Score를 나란히 표시한다.

## 상세

- Apple Sleep Score API가 공개되면 HealthKit에서 읽기
- DUNE 점수와 Apple 점수를 동일 차트에 dual-line으로 표시
- 차이가 큰 날짜에 인사이트: "DUNE은 WASO를 더 비중 있게 반영합니다"
- 사용자가 두 점수의 차이를 이해할 수 있도록 가중치 비교 설명

## 선행 조건

- Apple이 Sleep Score API를 공개해야 함 (현재 미공개)
- `HKQuantityType` 또는 `HKCategoryType`에 Sleep Score 추가 시 착수

## 참고

- watchOS 26에서 Apple Sleep Score가 Watch 앱에 표시되지만 API 접근은 아직 불가
- API 공개 시점 미정 — 장기 보류 항목
