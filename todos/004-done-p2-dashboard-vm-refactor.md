---
source: review/architecture+performance
priority: p2
status: done
created: 2026-02-15
updated: 2026-02-22
---

# DashboardViewModel SRP 리팩토링

## Issue
DashboardViewModel이 7+ 책임 보유. buildRecentScores 7회 중복 계산, sortedMetrics 매 접근 재정렬.

## Files
- `Dailve/Presentation/Dashboard/DashboardViewModel.swift`
- 새 파일: `Domain/UseCases/LoadDashboardDataUseCase.swift`

## Fix
1. sortedMetrics를 캐싱 또는 metrics 설정 시 정렬
2. buildRecentScores 중복 계산 제거 (baseline 1회 계산, 재사용)
3. 데이터 fetching을 UseCase로 추출 (장기)
