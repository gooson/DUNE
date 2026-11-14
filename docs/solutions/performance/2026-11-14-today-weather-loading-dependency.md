---
tags: [today, dashboard, daily-digest, weather, async, loading, cancellation]
category: performance
date: 2026-11-14
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNETests/DashboardViewModelTests.swift
  - DUNEUITests/Full/NotificationRoutingRegressionTests.swift
related_solutions: []
---

# Today와 알림 요약의 날씨 로딩 의존 제거

## Problem

사용자가 오늘의 요약 알림으로 진입한 뒤 Today 스켈레톤이 2분 이상 유지됐고, 이후 화면이 나타났다고 보고했다. 다른 탭은 접근 가능했다.

### Root Cause

`DashboardViewModel.loadData()`는 건강 데이터 6종과 `safeWeatherFetch()`를 같은 `async let` tuple에서 기다렸다. 날씨 경로에는 위치 요청, 날씨·대기질 네트워크, reverse geocoding이 포함된다. 건강 데이터가 준비돼도 이 중 한 요청이 지연되면 지표 적용과 `hasLoadedOnce` 전환이 지연된다. 같은 ViewModel의 `loadData()` 반환을 기다리는 `DailyDigestNotificationView`도 영향을 받는다.

이 의존 관계는 코드와 응답을 보류하는 mock으로 확인했다. **신고된 실기기의 실제 지연 요청은 로그가 없어 확정하지 않았다.** HealthKit이나 권한 준비의 지연을 모두 해결했다는 의미는 아니다.

## Solution

| File | Change | Reason |
|------|--------|--------|
| `DashboardViewModel.swift` | 날씨를 별도 소유 `Task`로 갱신 | 건강 데이터·일간 요약 완료가 날씨 응답에 의존하지 않게 함 |
| `DashboardViewModel.swift` | load ID·공통 weather generation·취소 검사, weak capture, `isolated deinit` 취소 | background와 권한 재조회 양쪽의 과거 응답 덮어쓰기 및 ViewModel 보유를 방지 |
| `DashboardViewModel.swift` | 건강 데이터 표시 완료 후 늦게 도착한 날씨로 코칭·브리핑 갱신 | sparkline 마무리 중에도 문맥을 갱신하고, 같은 template의 AI 요청·강화 문구는 유지 |
| `DashboardViewModelTests.swift` | 지연 응답·요청 역전·권한 재조회 경합·문맥·AI 중복·수명 회귀 | 실제 Task 완료를 기다려 비필수 응답 보류와 역전 처리를 확인 |
| `NotificationRoutingRegressionTests.swift` | 요약 복귀 후 스켈레톤 종료·컨디션 카드 확인 및 캡처 | 실제 알림 경로의 완료 상태 확인 |

`review-ship`에서 P2 4건을 보완한 최종 `origin/main` 기반 소스는 `DashboardViewModelTests` **44건**이 통과했다. 최초 테마 작업 폴더의 40건 및 PNG는 보완 전 이력으로 구분한다. 최종 소스 해시·UI 결과·실행 환경·제한은 [리뷰·Ship 기록](../../reviews/2026-11-14-today-loading/review-ship.md)을 기준으로 한다.

## Prevention

- 비필수 외부 데이터가 첫 화면 전체의 로딩 완료 조건에 포함되지 않도록 호출 경계를 검토한다.
- 지연 mock은 취소에 협조하지 않아도 오래된 응답이 상태를 바꾸지 못하는지 확인한다.
- 비동기 작업은 갱신 시 이전 작업을 취소하고, weak capture를 `await` 뒤에 해제해 화면 수명을 연장하지 않는다.
- 같은 날씨 상태를 갱신하는 명시적 권한 재조회와 background 조회는 하나의 generation을 공유한다.
- 건강 데이터 표시 완료와 `isLoading` 종료는 구분한다. 비필수 sparkline 마무리 중에도 이미 표시된 데이터의 문맥을 갱신한다.
- 같은 AI template을 재생성할 때 진행 중 inference와 강화된 기존 문구를 보존한다.
- HealthKit 권한 대기는 실제 조회 완료와 구분한다. 날씨 분리를 이유로 권한 준비 중 스켈레톤을 먼저 없애지 않는다.
- 실기기 재발 시 건강 snapshot·날씨·권한 준비 중 지연 단계를 로그로 구분한다.

## Lessons Learned

병렬 요청이어도 모든 응답을 한 번에 기다리면 가장 느린 비필수 요청이 화면 전체의 응답 시간을 결정한다. 독립적으로 실패할 수 있는 데이터는 표시 완료 경계도 독립적으로 관리해야 한다.
