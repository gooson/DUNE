---
tags: [macOS, healthkit, cloudkit, swiftdata, sync, architecture]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: 맥 앱 실행을 위한 HealthKit 내재화 + Cloud Sync

## Problem Statement

현재 앱은 `iOS/watchOS`에서만 실행되며, 핵심 건강 지표(`HRV`, `RHR`, `Sleep`)는 `SharedHealthDataServiceImpl`이 HealthKit에서 직접 조회한다.  
하지만 macOS는 HealthKit 직접 접근이 불가하므로, 현재 구조를 그대로 옮기면 맥 앱에서 동일 기능을 제공할 수 없다.

목표는 iPhone/Watch에서 수집한 HealthKit 데이터를 앱 내부 표준 모델로 내재화하고 CloudKit으로 동기화해, 맥 앱이 동일 데이터를 읽어 실행 가능하도록 만드는 것이다.

## Target Users

- iPhone + Mac을 함께 사용하는 개인 사용자
- 운동/회복 데이터를 데스크탑 큰 화면에서 확인하고 싶은 사용자
- Apple Watch 운동 후 맥에서 추세 분석을 이어서 보고 싶은 사용자
- macOS 단독 사용이 아니라 iPhone을 보조 디바이스로 함께 사용하는 사용자

## Success Criteria

1. 맥 앱(`macOS target`)이 HealthKit 없이도 **모든 탭**을 조회 전용으로 렌더링한다.
2. iOS에서 수집된 건강 데이터가 CloudKit을 통해 맥에 자동 반영되고, **동기화 지연이 1분 이내**로 유지된다.
3. 데이터 신선도 표시(`lastSyncedAt`)가 제공되어 stale 상태를 사용자에게 명확히 전달한다.
4. 쓰기 권한 분리가 유지된다: HealthKit 원천 데이터의 내재화 기록은 iOS/watchOS만 작성하고, macOS는 읽기 중심으로 동작한다.
5. 기존 iOS/watchOS 동작(Observer, Background Delivery, Condition Score 계산)이 회귀 없이 유지된다.

## Current Architecture Analysis

### 현재 확인된 상태

- `DUNE/project.yml`에 `iOS`, `watchOS` 타겟만 존재
- `DUNEApp`에서 `HKHealthStore`, `HealthKitObserverManager`를 직접 사용
- `SharedHealthDataServiceImpl`이 HealthKit 쿼리 결과를 메모리 캐시(5분 TTL)로만 관리
- SwiftData + CloudKit는 이미 사용 중이지만, HealthKit 지표 전용 동기화 모델은 없음

### 핵심 갭

1. macOS 실행 타겟 부재
2. HealthKit 의존 서비스의 플랫폼 분리 미흡
3. HealthKit 결과를 CloudKit으로 내보내는 정규화/동기화 계층 부재

## Proposed Approach

### 권장안: "iOS 수집 + CloudKit 미러 + macOS 소비" 단일 파이프라인

#### 1) 데이터 내재화 모델 추가 (SwiftData + CloudKit)

HealthKit 원천 샘플을 맥에서 직접 재생성하려 하지 않고, 맥에서 필요한 수준으로 정규화한 미러 모델을 만든다.

- `HealthDailyMetricRecord` (예: `hrvDailyAvg`, `rhrDailyAvg`, `sleepTotalMinutes`)
- `HealthSleepBreakdownRecord` (deep/rem/core/awake 분해, 필요 시)
- `HealthSyncStatusRecord` (`lastSyncedAt`, `sourceDevice`, `schemaVersion`)

설계 원칙:
- CloudKit 호환을 위해 관계는 Optional 유지(`@Relationship ... ?`)
- enum rawValue/field name을 영구 계약으로 취급 (변경 시 migration 필수)
- timezone 기준 day-bucket(`startOfDay`)를 명시적으로 저장

#### 2) iOS/watchOS: HealthKit -> Mirror 동기화 Writer 추가

기존 `SharedHealthDataServiceImpl` fetch 완료 시점 또는 `AppRefreshCoordinator` 경로에서:

- HealthKit 조회 결과를 정규화
- 기존 미러 레코드와 diff 후 upsert
- `HealthSyncStatusRecord.lastSyncedAt` 갱신

추가 권장:
- "single writer" 원칙: 미러 데이터 작성은 iOS/watchOS만 수행
- macOS는 읽기 전용으로 유지하여 충돌/중복 writer 방지

#### 3) macOS Target 신설

`project.yml`에 `DUNEMac`(또는 Catalyst) 타겟을 추가하고, 다음을 분리한다.

- HealthKit import/use 경로 제거
- `CloudBackedSharedHealthDataService` 구현체로 미러 모델 조회
- 기존 ViewModel 계약은 유지하되, 데이터 소스만 DI로 교체

초기 MVP에서는 **모든 탭을 read-only로 제공**:
- Dashboard
- Activity
- Wellness
- Exercise
- Lifestyle
- Settings(동기화 상태/정보성 항목 중심)

전제:
- macOS는 편집/기록 기능 없이 조회 전용
- iPhone이 데이터 생산자(primary), macOS는 소비자(secondary)

#### 4) 서비스 추상화 계층 도입

현재 `SharedHealthDataService`를 플랫폼 무관 인터페이스로 유지하고 구현체를 분리한다.

- `SharedHealthDataServiceImpl` (iOS/watchOS, HealthKit 기반)
- `CloudMirroredHealthDataServiceImpl` (macOS, SwiftData/CloudKit 기반)

이 구조로 UI/Domain 변경을 최소화한다.

#### 5) 점진적 롤아웃

1. 스키마 추가 + migration + CloudKit 안정화
2. iOS writer 도입 (기존 기능 영향 최소화)
3. macOS 대시보드 read-only 릴리즈
4. 상세 화면/고급 지표 확장

## Constraints

### 기술적 제약

- macOS에서 HealthKit 직접 접근 불가
- CloudKit 전파 지연(수초~수분) 발생 가능
- 데이터량 증가 시 CloudKit 비용/성능 고려 필요
- SwiftData + CloudKit 스키마 변경 시 staged migration 안정성 관리 필요
- macOS 단독 모드는 범위 제외 (iPhone 보조수단 전제)

### 프로젝트 규칙 제약

- CloudKit relationship Optional 규칙 준수
- `VersionedSchema` 동기화 누락 금지
- 레이어 경계 유지: ViewModel에서 SwiftData 직접 접근 금지

## Edge Cases

1. iPhone이 장시간 오프라인이면 맥 데이터가 stale 상태로 남음
2. 사용자가 Cloud Sync를 비활성화하면 맥 최신화 중단
3. HealthKit 권한 철회 시 iOS writer가 갱신 불가
4. timezone 변경/일광절약시간 전환 시 일자 버킷 불일치 가능
5. 같은 시점의 Watch/iPhone 데이터 중복 반영 위험 (dedup key 필요)

## Scope

### MVP (Must-have)

- macOS 타겟 생성 및 앱 실행
- HealthKit 미러용 SwiftData 모델 추가
- iOS에서 미러 데이터 upsert 파이프라인 추가
- macOS에서 미러 데이터 조회 기반 **모든 탭** 조회 표시
- stale indicator(`lastSyncedAt`) 표시
- 1분 이내 동기화 SLA를 만족하기 위한 refresh/observer 튜닝

### Nice-to-have (Future)

- Anchored delta sync(변경분만 동기화)
- 충돌 해소 규칙 고도화(소스 우선순위/시간 근접 매칭)
- 맥에서 고해상도 운동 세션 타임라인 제공
- sync 상태 진단 UI(최근 오류/누락 지표)

## Confirmed Decisions

1. 맥 앱 MVP는 조회 전용(read-only)으로 진행
2. 범위는 특정 탭 제한이 아닌 모든 탭 포함
3. 동기화 목표는 1분 이내
4. 맥 단독 사용은 지원하지 않고 iPhone 보조수단으로 정의
5. 일정은 ASAP 우선순위로 진행

## Next Steps

- [ ] `/plan macos-healthkit-cloud-sync-internalization` 으로 구현 계획 생성
- [ ] plan 단계에서 탭별 read-only 허용/비허용 액션 매트릭스 확정
- [ ] 동기화 1분 SLA 검증 기준(측정 포인트, 실패 임계치) 정의
