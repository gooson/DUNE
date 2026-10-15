---
tags: [healthkit, ios27, limited-read-access, authorization, cold-launch, swiftdata, cloudkit]
category: architecture
date: 2026-10-14
severity: important
status: implemented
related_files:
  - DUNE/Data/HealthKit/HealthKitManager.swift
  - DUNE/Domain/Models/HealthDataAccessWindow.swift
  - DUNE/Data/Services/ScoreRefreshService.swift
  - DUNE/App/DUNEApp.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Shared/Detail/AllDataViewModel.swift
related_solutions:
  - docs/solutions/architecture/2026-03-11-launch-permission-deferral-stability.md
  - docs/solutions/performance/2026-09-19-all-metric-history-windows.md
---

# HealthKit의 기간 제한 읽기 권한을 기준선과 화면에 반영

## Problem

### Symptoms

iOS 27에서는 건강 데이터 종류마다 읽을 수 있는 기록의 시작일이 제한될 수 있다. 기존 쿼리는 더 이른 기록을 요청하고, HRV·안정시 심박수 기준선이 부족해도 화면에서 부분 데이터임을 설명하지 않았다. 설정 앱에서 권한 범위를 바꾼 뒤 저장된 최근 컨디션 점수가 이전 범위의 표본을 반영할 수도 있었다.

### Root Cause

HealthKit 읽기 권한은 앱이 쓰기 권한 상태를 조회하는 방식으로 확인할 수 없다. 제한 시작일은 데이터 종류별로 확인해야 하며, 결과가 없는 경우는 전체 허용과 거부를 구분하지 못한다. 앱 재시작 시 메모리의 직전 시작일이 사라지므로 포그라운드 비교만으로는 종료 중 변경을 감지할 수 없다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `HealthKitManager`, `HealthDataAccessWindow` | `earliestAuthorizedSampleDate(for:)` 결과를 종류별로 저장하고 앱 재시작 후 비교한다. 변경 사실은 최근 점수 무효화가 끝날 때까지 로컬에 유지한다. | 종료 중 권한 변경과 인가 경로의 조기 갱신을 놓치지 않기 위해 |
| HRV/RHR 쿼리 서비스 | 점 표본 조회 시작일을 확인된 제한 시작일 이후로 조정한다. | 허용 범위 밖 표본 요청을 피하기 위해 |
| 대시보드·상세 화면 | HRV 또는 안정시 심박수의 기준선 기간이 제한되면 부분 기록 안내를 표시한다. | 점수가 존재해도 해석 범위를 알리기 위해 |
| `AllDataViewModel` | 권한 시작일 조회가 끝난 뒤 첫 페이지를 열고, 반환된 표본도 시작일 이후로 제한한다. | 목록의 자동 페이지 작업이 먼저 실행되어 권한 조회 결과를 폐기하거나 테스트 표본의 오래된 기록을 표시하지 않기 위해 |
| `ScoreRefreshService`, `DUNEApp` | 권한 경계 변경 시 현재 표시하는 24시간 컨디션·HRV·RHR 스냅샷만 비우고 새로고침한다. | 오래된 점수 표시를 막으면서 전체 CloudKit 기록의 일괄 재작성을 피하기 위해 |

### Key Code

```text
인가 또는 앱 재진입 → 종류별 시작일 갱신 → 저장한 이전 시작일과 비교
→ 조건 점수에 쓰이는 종류가 바뀌었으면 변경 사실을 보관
→ 최근 24시간의 파생 점수 무효화 → 보관한 변경 사실을 해제 → 새 점수 조회
```

시작일이 없는 데이터 종류는 전체 읽기 허용으로 추측하지 않는다. 쿼리는 기존 범위를 유지하고, 변경 감지에서는 안전하게 최근 파생 점수를 다시 계산한다. 과거 24시간을 넘는 시간별 스냅샷은 현재 컨디션 스파크라인에서 읽지 않으므로 CloudKit에 대량 변경을 만들지 않는다.

## Prevention

- 새 HealthKit 기준선 계산을 추가하면 필요한 데이터 종류의 제한 시작일을 각각 확인한다.
- 인가 요청 자체가 시작일 캐시를 갱신할 수 있으므로, 앱 재진입과 첫 인가 경로를 모두 테스트한다.
- 권한 변경 후 파생 점수를 지울 때 해당 화면의 실제 조회 기간을 확인하고, 전체 저장 기록을 무조건 수정하지 않는다.
- 새 장기 컨디션 기록 화면을 만들면 오래된 스냅샷의 권한 범위 해석을 별도 설계한다.
- 목록의 첫 페이지 로딩과 권한 경계 조회가 동시에 시작되지 않도록 상태 전이를 테스트한다. 실제 화면 캡처에서 안내와 데이터 날짜를 함께 확인한다.

## Lessons Learned

HealthKit 읽기 허용 기간은 전역 불리언이 아니라 데이터 종류별 시간 경계다. 현재 경계와 그 변경 사실을 로컬에 유지해야 앱이 꺼진 동안 바뀐 권한도 처리할 수 있다. 기록 범위가 바뀌면 화면에 표시되는 파생 결과의 유효 범위도 함께 갱신해야 한다.
