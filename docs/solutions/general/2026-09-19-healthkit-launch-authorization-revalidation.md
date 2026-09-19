---
tags: [healthkit, authorization, launch, today, cache]
date: 2026-09-19
category: general
status: implemented
severity: important
related_files: [DUNE/App/DUNEApp.swift, DUNE/App/LaunchExperiencePlanner.swift, DUNETests/LaunchExperiencePlannerTests.swift]
---

# Today HealthKit 권한 재확인

## Problem

Today에서 건강 데이터를 불러올 수 없다는 화면이 반복되었다. 제공된 로그에는 `Authorization not determined`, query skipped, `rhrCollection` 실패가 반복되었다.

기존 launch 정책은 UserDefaults의 `hasRequestedHealthKitAuthorization`이 true이면 HealthKit 요청을 영구 생략하면서 Today 조회를 허용했다. 저장된 플래그는 현재 기기 권한이나 새로 추가된 데이터 타입의 요청 완료를 보장하지 않는다. 사용자 기기에서 플래그가 어긋난 경위는 확인되지 않았다. observer도 권한 요청 전에 시작되고 있었다.

## Solution

- HealthKit은 저장된 완료 값과 무관하게 실행마다 한 번 requestAuthorization을 호출한다. 실제 권한 UI 표시는 HealthKit이 결정한다.
- 알림의 기존 완료 플래그 정책, 실행 중 중복 요청 방지, 테스트 bypass, HealthKit 미지원 기기 가드는 유지한다.
- Today 조회 허용은 이번 실행의 요청 완료 상태를 사용한다. 요청 완료는 읽기 허용 여부를 의미하지 않는다.
- 완료 후 기존 캐시를 무효화하고 observer 시작 및 강제 refresh를 수행한다.

## Validation

- `scripts/build-ios.sh --no-regen`: iOS 빌드 성공.
- 실제 planner 소스 및 `LaunchExperiencePlannerTests.swift`를 임시 Swift package로 복사해 macOS Swift Testing 실행: 12개 테스트 통과.
- 저장된 완료 값 true/false 재확인, 동일 실행 재요청 차단, 미지원 기기 및 테스트 bypass 검증.
- 실기기의 HealthKit 권한 UI와 데이터 복구는 미검증. 수정 빌드로 재실행 후 확인 필요.

## Prevention

앱 자체의 권한 요청 이력을 시스템의 현재 권한 상태로 간주하지 않는다. 권한 완료 후에는 권한 이전에 만들어진 빈 snapshot이나 실패 캐시를 무효화한다.

## Lessons Learned

CloudKit refresh 로그가 많아도 직접적인 데이터 로드 실패 원인은 HealthKit 권한일 수 있다. 호출 반복과 실제 실패 원인을 분리해 분석해야 한다.
