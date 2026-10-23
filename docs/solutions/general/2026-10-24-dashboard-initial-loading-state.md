---
tags: [dashboard, swiftui, skeleton, startup, healthkit, empty-state, authorization]
category: general
date: 2026-10-24
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNETests/DashboardViewModelTests.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
related_solutions:
  - 2026-03-13-dashboard-smooth-transitions.md
---

# Solution: Today 첫 조회 전 빈 상태 노출 방지

## Problem

앱 시작 시 실제 측정 기록이 있어도 먼저 “아직 측정 기록이 없어요”가 표시됐다.

### Root Cause

`sortedMetrics`의 초기값은 빈 배열이고 `isLoading`은 `false`다. SwiftUI가 `.task`를 시작하기 전 첫 렌더가 빈 상태 조건을 만족했다. 또한 앱의 HealthKit 권한 준비가 끝나기 전에 실행된 조회는 보호된 쿼리를 생략하므로, 이 결과의 빈 배열도 실제 기록 없음으로 표시됐다. View의 `hasAppeared`는 카드 등장 애니메이션 상태이며 조회의 완료 여부를 보장하지 않는다.

## Solution

기존 `hasLoadedOnce`와 권한 준비 상태를 함께 사용하는 `shouldShowSkeleton`으로 표시 분기를 결정한다.

| 상태 | 표시 |
|---|---|
| 첫 조회 시작 전·미완료·취소 | 스켈레톤 |
| HealthKit 권한 준비 중 | 스켈레톤 |
| 측정값 없이 새로고침 중 | 스켈레톤 |
| 기존 측정값이 있는 새로고침 | 기존 콘텐츠 유지 |
| 조회 완료 후 실제 측정값 없음 | 기존 빈 상태 |
| 조회 실패·권한 요청 실패 | 기존 오류·권한 안내 |
| HealthKit 미지원 mirror 모드 | 기존 CloudKit 대기·콘텐츠 |

기존 `DashboardSkeletonView`를 재사용해 테마와 기기별 배치는 유지한다. UI 테스트는 기존 `--ui-defer-daily-digest-healthkit` fixture로 대기 상태를 고정하고 background → foreground 전환으로 실제 준비 완료 경로를 검증한다. 단위 테스트는 continuation으로 첫 빈 응답, 첫 데이터 응답, 권한 대기·실패, 이전 요청 취소, 새로고침을 검증한다.

권한 대기 중 생략한 조회는 `hasLoadedOnce`를 갱신하지 않는다. 권한 준비가 완료된 뒤 새 `.task`가 시작되기 전에도 스켈레톤을 유지하기 위해서다. 권한 요청 실패는 첫 조회 완료 여부와 별도로 기존 권한 안내를 표시할 수 있게 한다.

### 검증 범위

- Swift 구문 검사, String Catalog 포맷 검사와 diff 공백 검사를 통과했다.
- 단위 테스트 6개를 추가했다. 첫 빈 응답·측정값 응답·권한 대기와 실패·단독 첫 조회 취소·이전 요청 취소·기존 콘텐츠 새로고침을 검증한다. 권한 대기 테스트는 HealthKit 지원 환경에서만 실행한다.
- UI 테스트 2개는 준비 중 스켈레톤 유지, 조회 완료 시 전환, mock 측정값 표시를 검증한다. 앱 초기화로 기존 HealthKit 기록이 삭제되지 않으므로 첫 조회 완료 테스트는 기기에 기록이 없다고 가정하지 않는다. 결정적인 빈 응답은 단위 테스트로 검증한다.
- 기존 `e1e6` 워크트리에서 발생한 소유권 등록 실패는 중간 subprocess가 잠금 FD를 닫으면서 생긴 `Bad file descriptor`였다. 별도 `main` 기반 워크트리에서는 외부 셸이 잠금을 유지하고 metadata subprocess에서 오래된 FD 환경값을 제거하여 전용 기기 소유권 등록을 확인했다. 저장소 실행기 소스는 수정하지 않았다.
- 새 전용 iPhone `E64BD58C-CD2F-46D6-BBEB-AFC6FB578B81`에서 관련 단위 테스트를 시작하려 했지만, 다른 워크트리의 진행 중인 UI 검증이 저장소 잠금을 보유해 60초 대기 후 시작하지 못했다. 같은 상태에서 다시 실행하지 않았다. 테스트 실행 통과로 보고하지 않는다.
- T03 초기 스켈레톤·조회 완료 빈 상태·측정값 표시 상태의 새 캡처는 iPhone·iPad·Duo 접힘·펼침 모두 미완료다. Watch는 해당 `DashboardView`를 사용하지 않아 영향이 없다. 기존 이미지는 이번 구현의 증거가 아니다.
- 재개 조건: 진행 중인 저장소 테스트의 정상 종료와 잠금 해제를 확인한 뒤, 소유권이 등록된 전용 기기에서 `DUNEUITests/DashboardLoadingTests`를 실행하고 새 PNG를 수집한다.

## Prevention

- 빈 배열과 `isLoading == false`만으로 첫 조회가 완료됐다고 판단하지 않는다.
- 권한 준비 때문에 생략한 조회 결과와 실제 빈 조회 결과를 구분한다.
- 애니메이션 상태를 데이터 조회 완료 상태로 사용하지 않는다.
- 재조회에서는 기존 콘텐츠를 유지하고, 취소·이전 응답이 첫 조회 완료 상태를 바꾸지 않는지 검증한다.

## Lessons Learned

시작 화면의 로딩 상태에는 비동기 조회뿐 아니라 조회를 시작할 수 있게 만드는 권한 준비도 포함해야 한다.
