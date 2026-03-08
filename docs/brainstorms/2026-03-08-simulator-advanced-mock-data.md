---
tags: [simulator, mock-data, settings, debug, healthkit, ios, visionos, workout]
date: 2026-03-08
category: brainstorm
status: approved
---

# Brainstorm: Simulator 전용 Advanced Mock Data 주입

## Problem Statement

현재 iPhone simulator와 Vision Pro simulator에서는 실제 HealthKit 데이터가 없거나 불안정해서, 건강/운동 화면을 "데이터가 가득 찬 상태"로 빠르게 검증하기 어렵다.

- iOS 앱은 UI 테스트용 `TestDataSeeder`가 있지만 런타임에서 수동으로 실행하는 설정 기능은 없다.
- visionOS 앱은 `SettingsView`를 공유하지 않고 별도 utility/window 구조를 사용하므로 동일한 디버그 진입점이 없다.
- 기존 mock 데이터는 smoke/UI test 중심이라 운동 종류와 rich workout field, per-exercise history, 고급 vitals 조합이 충분히 채워지지 않는다.
- 결과적으로 simulator 기반 UI 검증, QA, 캡처, 디자인 리뷰, 회귀 확인이 실제 제품 상태보다 빈약한 데이터에 묶인다.

## Target Users

- iPhone simulator에서 화면/회귀를 빠르게 확인하는 iOS 개발자
- Vision Pro simulator에서 spatial dashboard와 activity surface를 확인하는 visionOS 개발자
- 실제 HealthKit 없이 고밀도 샘플 데이터를 보고 싶은 QA/디자인 리뷰 사용자

핵심 니즈:

- 설정에서 한 번의 액션으로 고급 mock 데이터를 넣고 싶다.
- simulator에서만 안전하게 동작해야 한다.
- 앱 재실행 후에도 데이터가 유지되어야 한다.
- 운동 요약뿐 아니라 운동 종류별 상세 데이터와 per-exercise 기록도 충분히 채워져야 한다.

## Success Criteria

1. 기능은 simulator에서만 노출되고 실행된다.
2. iOS simulator와 visionOS simulator 모두에서 동일한 advanced mock dataset을 주입할 수 있다.
3. mock dataset은 reset 전까지 유지된다.
4. 현재 앱이 수집/표시하는 건강 지표가 모두 채워진다.
5. 운동 데이터는 단일 running fixture가 아니라 여러 운동 타입과 rich workout field를 포함한다.
6. per-exercise history, template/quick start 관련 운동 데이터도 함께 채워져 Activity/Exercise 화면이 충분히 populated 된다.
7. watchOS는 이번 범위에서 제외한다.

## Current State

### Existing Seeding Assets

- iOS 앱에는 UI 테스트용 `TestDataSeeder`가 존재한다.
- `SharedHealthSnapshot`, `HealthSnapshotMirrorRecord`, `WorkoutSummary` mock 생성 로직이 일부 있다.
- Activity 화면 일부는 `--seed-mock` 시나리오에서 workout detail fallback을 이미 사용한다.

### Gaps

- 설정에서 수동 실행 가능한 runtime seeding entry가 없다.
- visionOS에는 settings-equivalent debug surface가 없다.
- 기존 seeded data는 advanced athlete 수준의 장기 추세, 다종 운동, per-exercise history를 충분히 만들지 않는다.
- dataset reset 정책, persistence 정책, simulator guard가 제품 기능으로 정리되어 있지 않다.

## Proposed Approach

### 1. Simulator-only Entry Surface

- iOS: `SettingsView`에 simulator에서만 보이는 `Mock Data` 섹션을 추가한다.
- visionOS: 현재 공용 `SettingsView`가 없으므로 dashboard/utility toolbar에서 여는 settings-equivalent `Mock Data` sheet 또는 utility panel을 추가한다.
- 버튼은 MVP에서 두 개만 둔다.
  - `Seed Advanced Mock Data`
  - `Reset Mock Data`
- 실제 디바이스에서는 섹션/진입점 자체를 완전히 숨긴다.

### 2. One Advanced Scenario

- 시나리오는 MVP에서 `Advanced Athlete` 1종만 제공한다.
- seed 실행 시 기존 로컬 mock 관련 데이터를 wipe한 뒤 deterministic dataset으로 다시 채운다.
- merge가 아니라 wipe-and-reseed 정책을 사용해 결과 예측 가능성을 유지한다.

### 3. Seed Coverage

#### Health Data

- `SharedHealthSnapshot` 기반 건강 지표 전체를 채운다.
- 범위:
  - HRV
  - Resting Heart Rate
  - Sleep stages / daily sleep durations
  - Steps
  - Weight
  - BMI
  - Body Fat
  - Lean Body Mass
  - SpO2
  - Respiratory Rate
  - VO2 Max
  - Heart Rate Recovery
  - Wrist Temperature
  - condition score / recent trend

#### Workout Data

- 최근 30~60일 기준의 다종 운동 기록을 넣는다.
- 범위:
  - running
  - walking
  - hiking
  - cycling
  - swimming
  - stair/stair stepper 계열
  - strength / gym-style sessions
- 각 workout에는 가능한 rich field를 함께 채운다.
  - calories
  - distance
  - heartRateAvg / Max / Min
  - averagePace / averageSpeed
  - elevationAscended
  - weatherTemperature / condition / humidity
  - isIndoor
  - effortScore
  - stepCount
  - flightsClimbed
  - milestoneDistance
  - personalRecord flags

#### Per-Exercise Data

- Activity/Exercise 계열 화면을 채우기 위해 운동별 기록도 함께 넣는다.
- 범위:
  - `ExerciseRecord` 장기 히스토리
  - strength exercise별 반복 등장 기록
  - 여러 muscle group/equipment 조합
  - custom exercise / user category 최소 fixture
  - workout template / quick start 관련 fixture
- 목표는 "운동 summary만 보이는 상태"가 아니라 exercise detail, history, recommendation, template entry point까지 자연스럽게 populated 된 상태다.

### 4. Data Ownership and Persistence

- dataset은 SwiftData / mirrored snapshot storage에 저장한다.
- app relaunch 후 유지한다.
- reset 시에만 삭제한다.
- mock dataset 여부를 로컬 플래그로 기록해 reset 가능 상태와 중복 seed 방지를 관리한다.

### 5. Architecture Direction

- UI test 전용 `TestDataSeeder`의 factory/helper를 재사용 가능한 domain-level/mock seeding utility로 승격한다.
- launch argument 의존 로직과 runtime button 의존 로직을 분리하되, 실제 fixture 생성 함수는 공유한다.
- iOS와 visionOS가 같은 dataset builder를 공유하고, 각 target은 자기 storage/container 진입점만 다르게 가진다.

## Constraints

- simulator guard는 compile-time + runtime 양쪽에서 확실해야 한다. 실디바이스에서 accidental exposure가 없어야 한다.
- visionOS는 현재 iOS `SettingsView`를 그대로 쓰지 않으므로 별도 debug entry 설계가 필요하다.
- HealthKit 직접 query path와 mirrored/local snapshot path가 target별로 달라, seed가 어느 저장 계층을 채워야 각 화면이 실제로 읽는지 정리해야 한다.
- wipe-and-reseed는 mock 관련 로컬 데이터를 명확히 식별할 수 있어야 안전하다.
- UI 테스트용 기존 `--seed-mock` 시나리오와 새 runtime mock 기능의 책임 경계를 분리해야 한다.

## Edge Cases

- seed 버튼을 여러 번 눌러도 중복 record가 누적되지 않아야 한다.
- reset 없이 재-seed하면 이전 mock dataset을 정리한 뒤 동일 상태로 복원해야 한다.
- 일부 화면은 HealthKit direct query, 일부 화면은 mirrored/local SwiftData를 읽을 수 있으므로 데이터 소스 불일치가 나지 않아야 한다.
- visionOS simulator에서 HealthKit availability가 target/runtime에 따라 다를 수 있어도 seeded dataset이 안정적으로 보이도록 해야 한다.
- mock dataset이 실제 사용자 데이터와 섞여 보이면 혼동될 수 있으므로 simulator 범위 안에서도 mock origin 표시 여부를 검토해야 한다.

## Scope

### MVP (Must-have)

- [x] iOS simulator `Settings`의 `Mock Data` 섹션
- [x] visionOS simulator용 settings-equivalent `Mock Data` entry
- [x] `Advanced Athlete` 단일 시나리오
- [x] wipe-and-reseed 정책
- [x] reset 기능
- [x] 앱 재실행 후 유지
- [x] 현재 수집 건강 지표 전체 seed
- [x] 다종 workout + rich workout field seed
- [x] per-exercise history / template fixture seed
- [x] watch 제외

### Nice-to-have (Future)

- [ ] multiple mock personas
- [ ] partial seed options (`Vitals only`, `Workout only`)
- [ ] mock badge / banner
- [ ] screenshot/demo 전용 deterministic date override
- [ ] watch simulator fixture parity

## Open Questions

- visionOS의 exact entry UI는 구현 단계에서 결정한다.
  - 후보: toolbar button + sheet
  - 후보: utility panel
- mock origin을 화면에서 명시적으로 표시할지는 구현 단계에서 결정한다.

## Next Steps

- [ ] `/plan simulator advanced mock data`로 구현 계획 생성
