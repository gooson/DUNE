---
source: brainstorm/2026-03-28-sleep-analysis-enhancement
priority: p3
status: done
created: 2026-03-29
updated: 2026-03-29
---

# Apple Health 스타일 Vitals 통합 뷰

## 설명

HR, 호흡수, 손목 온도, SpO2, 수면을 하나의 통합 차트로 시각화한다.

## 상세

- Apple Health의 Vitals 통합 차트 UX를 참고
- 30일 타임라인에 5개 바이탈 트랙을 vertical stack
- 각 트랙: 일별 min/max 범위 + 평균 라인
- 이상치 날짜 자동 하이라이트 (baseline 대비 ±2σ)
- Wellness 탭 또는 Sleep 상세에 배치
- 기존 `VitalsQueryService`, `HeartRateQueryService` 재활용

## 선행 조건

- MVP 4 (야간 바이탈 대시보드) 완료 — 완료됨

## 참고

- iOS 26.4 Apple Health의 Vitals 화면 참고
- 차트 렌더링 성능: 30일 × 5트랙 = 150 데이터 시리즈 → LazyVStack 격리 필수
