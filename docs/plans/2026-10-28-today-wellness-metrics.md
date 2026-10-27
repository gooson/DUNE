---
tags: [today, wellness, metrics, equal-height, swiftui]
date: 2026-10-28
category: plan
status: in-progress
---

# Today 지표 카드 통일과 행 높이

## 문제와 완료 기준

고정 지표에서 비교값/추세가 없는 체중 카드가 수면 카드보다 낮다. Wellness의 범주색·옅은 내부 면·큰 기본색 수치·실제 관측 추세·측정일을 Today 지표에 맞춘다. 같은 두 열 행은 가장 큰 자연 높이를 사용하고 큰 글씨의 한 열·홀수 전체 폭·운동 행의 조밀한 표시를 유지한다.

## Affected Files

| 파일 | 변경 |
|---|---|
| TodayMetricCard.swift | Wellness 계층·비교 없음·자연 높이 측정 Layout |
| DashboardView.swift | 기존 두 열 행에 동일 높이 제안 |
| DashboardViewModel.swift | 기존 HRV/RHR·수면 기록만 유효한 최근 추세로 전달. 추가 조회 없음 |
| DashboardViewModelTests.swift | 실제 순서·관측1개·신체 이력 미생성 |
| TodayCompactUITests.swift | 네 고정 지표의 행 높이·큰 글씨·상세·새 캡처 |

## Implementation Steps

1. 기존 Today 상태 계약·Wellness 카드와 높이 차이를 대조한다.
2. V1 범주색/수치, V2 옅은 면/실제 추세와 자연 높이 행을 적용한다.
3. 전용 iPhone에서 밝음·어두움·최대 글씨, 홀수와 운동 행을 확인한다.
4. 기존 관측 전달의 unit 검사와 iPad 두 열 상태를 확인한다. 전체 UI 회귀는 실행하지 않는다.
5. 새 실제 화면·출처·검증 범위를 디자인맵에 보존한다. Duo 미실행 상태를 구분한다.
