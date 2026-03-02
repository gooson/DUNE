---
tags: [watchos, workout-template, watchconnectivity, cloudkit, fallback-sync]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNE/Presentation/Exercise/Components/WorkoutTemplateListView.swift
  - DUNE/App/DUNEApp.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNEWatchTests/WatchExerciseHelpersTests.swift
related_solutions:
  - docs/solutions/general/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
  - docs/solutions/general/2026-02-28-watch-routine-equipment-icon-enrichment.md
---

# Solution: iPhone에서 만든 운동 템플릿이 Watch에 보이지 않는 동기화 공백

## Problem

### Symptoms

- iPhone에서 `WorkoutTemplate`를 생성/수정/삭제해도 Watch 루틴 카드에 즉시 반영되지 않음
- 특히 iPhone CloudKit 동기화가 꺼져 있거나 지연되는 환경에서 Watch의 루틴 목록이 비어 있거나 오래된 상태로 남음

### Root Cause

Watch 루틴 화면은 SwiftData + CloudKit `@Query(WorkoutTemplate)`를 primary source로 사용하고,
WatchConnectivity는 `exerciseLibrary`만 전송하고 있었다.

즉, 템플릿은 CloudKit 경로 하나에만 의존했고, iPhone↔Watch 간 즉시 동기화 fallback이 없었다.

## Solution

CloudKit 경로는 유지하고, 템플릿에 대해 WatchConnectivity fallback 동기화를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WatchConnectivityModels.swift` | `WatchWorkoutTemplateInfo` DTO 추가 | 템플릿 전송 포맷 단일화 |
| `WatchSessionManager.swift` | 템플릿 fetch/sync, cache, request-response 처리 추가 | iPhone 기준 템플릿 snapshot을 Watch로 전송 |
| `DUNEApp.swift` | 앱 부팅 시 템플릿 sync 선행 호출 | 세션 활성화 직후 빈/구버전 상태 방지 |
| `WorkoutTemplateListView.swift` | 템플릿 목록 변화(onAppear/count/updatedAt) 시 sync 호출 | 생성/수정/삭제 직후 즉시 반영 |
| `WatchConnectivityManager.swift` | `workoutTemplates` 수신 상태 + 재요청 경로 추가 | Watch 측 pull-request/fallback 확보 |
| `WatchExerciseHelpers.swift` | local+synced 템플릿 병합 helper 추가 | CloudKit/WC 하이브리드 source 처리 |
| `CarouselHomeView.swift` | 루틴 카드 소스를 병합 템플릿으로 전환 | CloudKit 미반영 시에도 Watch에 루틴 표시 |
| `WatchExerciseHelpersTests.swift` | 병합 우선순위/정렬 테스트 추가 | local 우선 + fallback 회귀 방지 |

### Key Design

- **Source of truth**: CloudKit `WorkoutTemplate` 유지
- **Fallback**: WatchConnectivity `WatchWorkoutTemplateInfo` 추가
- **Merge policy**:
  - ID 중복 시 local(CloudKit) 우선
  - local 미존재 시 WC 템플릿 사용
  - `updatedAt` 내림차순 정렬

## Prevention

### Checklist

- [ ] Watch 화면이 CloudKit 모델을 primary로 쓰더라도, 사용자 체감 지연이 큰 데이터는 WC fallback 경로를 함께 설계한다.
- [ ] `updateApplicationContext` 사용 시 key overwrite를 피하고 기존 context를 merge한다.
- [ ] Watch에서 missing payload 상태(`exerciseLibrary`/`workoutTemplates`)를 성공 상태로 오표시하지 않는다.
- [ ] 병합 로직(local vs synced)은 순수 함수로 분리하고 우선순위/정렬 테스트를 추가한다.

## Verification

- iOS build: `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'generic/platform=iOS' ... build`
- Watch build: `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEWatch -destination 'generic/platform=watchOS' ... build`
- Watch unit test: `DUNEWatchTests/WatchExerciseHelpersTests` 통과
