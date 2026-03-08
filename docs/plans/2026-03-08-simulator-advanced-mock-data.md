---
topic: simulator-advanced-mock-data
date: 2026-03-08
status: approved
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
  - docs/solutions/architecture/2026-03-07-visionos-mirror-sync-gating-and-spatial-fallback.md
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-simulator-advanced-mock-data.md
---

# Implementation Plan: Simulator Advanced Mock Data

## Context

iOS simulator와 visionOS simulator에서 실제 HealthKit 없이도 건강/운동 데이터가 가득 찬 상태를 재현할 수 있어야 한다. 현재는 UI 테스트용 `TestDataSeeder`와 일부 mirrored snapshot fallback만 존재하고, 런타임에서 수동으로 실행하는 설정 기능이나 visionOS용 debug entry가 없다. 또한 여러 화면이 여전히 HealthKit query service를 직접 생성하므로, 단순히 SwiftData record만 seed하면 일부 detail/vision surface는 빈 상태로 남을 수 있다.

## Requirements

### Functional

- iOS simulator `Settings`에 `Mock Data` 섹션을 추가한다.
- visionOS simulator에 settings-equivalent `Mock Data` 진입점을 추가한다.
- `Advanced Athlete` 단일 시나리오의 seed/reset 액션을 제공한다.
- seed는 wipe-and-reseed 정책을 사용한다.
- mock dataset은 reset 전까지 유지된다.
- 현재 앱이 수집/표시하는 health/workout 관련 지표가 populated 된다.
- per-exercise history, custom exercise, user category, template fixture도 함께 채운다.
- watchOS는 범위에서 제외한다.

### Non-functional

- simulator에서만 노출/실행되어야 한다.
- 기존 UI test seeding과 dataset 정의가 분기되지 않도록 최대한 공유한다.
- visionOS는 앱 재실행 없이 mock mode 토글 후 데이터를 다시 읽을 수 있어야 한다.
- build/test 가능한 구조여야 하고, query service가 mock mode에서 deterministic 결과를 반환해야 한다.

## Approach

공유 dataset/provider를 중심으로 설계한다. 기존 `TestDataSeeder`의 fixture 생성 함수를 reusable layer로 승격하고, simulator mock mode를 나타내는 persisted flag를 추가한다. SwiftData 기반 화면은 seed/reset 액션으로 데이터를 저장하고, HealthKit query service 기반 화면은 mock mode일 때 공통 provider를 직접 참조해 deterministic 데이터를 반환하도록 만든다.

visionOS는 현재 `DUNEVisionApp`이 init 시점에 service 구성을 결정하므로, mock mode 토글 후에도 동작하도록 app/service 선택을 mock-aware하게 조정해야 한다. iOS는 simulator에서 mirrored snapshot + local SwiftData를 활용하되, direct query service들도 동일 mock provider를 사용하게 만들어 detail 화면까지 범위를 넓힌다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| SwiftData/HealthSnapshotMirror만 seed하고 기존 service는 그대로 유지 | 구현이 단순하고 기존 UI test 자산 재사용이 쉽다 | visionOS Train, detail 화면, direct query consumer가 빈 상태로 남을 수 있다 | 기각 |
| root view / view model마다 mock service를 주입 | 서비스별 제어가 명시적이다 | 주입 경로가 넓고 누락 위험이 크다 | 부분 기각 |
| HealthKit query service 공통 mock provider + runtime seed/reset | 기존 composition을 크게 바꾸지 않고 iOS/visionOS 양쪽 detail까지 커버 가능 | provider 설계와 여러 service guard가 필요하다 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/TestDataSeeder.swift` | update | fixture 생성 함수를 runtime seeding에서 재사용 가능하게 정리 |
| `DUNE/Data/Services/SimulatorAdvancedMockData*.swift` | add | simulator mock mode store, dataset provider, seed/reset coordinator 추가 |
| `DUNE/Data/HealthKit/WorkoutQueryService.swift` | update | mock mode일 때 deterministic workout dataset 반환 |
| `DUNE/Data/HealthKit/HRVQueryService.swift` | update | mock mode일 때 HRV/RHR dataset 반환 |
| `DUNE/Data/HealthKit/SleepQueryService.swift` | update | mock mode일 때 sleep stages/durations 반환 |
| `DUNE/Data/HealthKit/StepsQueryService.swift` | update | mock mode일 때 steps dataset 반환 |
| `DUNE/Data/HealthKit/VitalsQueryService.swift` | update | mock mode일 때 SpO2/resp/VO2/HRR/wrist temp dataset 반환 |
| `DUNE/Data/HealthKit/BodyCompositionQueryService.swift` | update | mock mode일 때 weight/body fat/lean mass/BMI dataset 반환 |
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | update | mock mode일 때 workout/general heart rate timeline/history 반환 |
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | update | mock mode일 때 snapshot provider 우선 |
| `DUNE/Presentation/Settings/SettingsView.swift` | update | iOS simulator-only `Mock Data` 섹션/상태/AXID 추가 |
| `DUNEVision/App/DUNEVisionApp.swift` | update | visionOS mock-aware service selection 및 refresh wiring 보강 |
| `DUNEVision/App/VisionContentView.swift` | update | visionOS mock entry 재로드 신호/utility 진입점 연결 |
| `DUNEVision/Presentation/**/Vision*MockData*.swift` | add | visionOS용 mock data sheet/panel UI 추가 |
| `Shared/Resources/Localizable.xcstrings` | update | 새 사용자 대면 문자열 등록 |
| `DUNETests/*MockData*Tests.swift` | add | provider/mode/seeding/service fallback 테스트 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | settings mock data AXID 상수 추가 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | update | simulator-only mock section smoke 검증 추가 |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | update | 새 소스 파일 반영을 위한 regen 결과 |

## Implementation Steps

### Step 1: Shared mock mode and dataset foundation

- **Files**: `DUNE/App/TestDataSeeder.swift`, `DUNE/Data/Services/SimulatorAdvancedMockData*.swift`
- **Changes**:
  - persisted mock mode flag + simulator guard 유틸 추가
  - reusable `Advanced Athlete` dataset builder 정의
  - SwiftData seed/reset coordinator 추가
  - HealthSnapshot mirror payload, workout fixtures, vitals/body/steps/heart-rate fixture를 공통 provider에서 생성
- **Verification**:
  - unit test로 mock mode enable/disable, dataset shape, seed/reset idempotence 확인

### Step 2: Make shared query services mock-aware

- **Files**: `DUNE/Data/HealthKit/WorkoutQueryService.swift`, `DUNE/Data/HealthKit/HRVQueryService.swift`, `DUNE/Data/HealthKit/SleepQueryService.swift`, `DUNE/Data/HealthKit/StepsQueryService.swift`, `DUNE/Data/HealthKit/VitalsQueryService.swift`, `DUNE/Data/HealthKit/BodyCompositionQueryService.swift`, `DUNE/Data/HealthKit/HeartRateQueryService.swift`, `DUNE/Data/Services/SharedHealthDataServiceImpl.swift`
- **Changes**:
  - mock mode일 때 HealthKit query 전에 provider fallback 실행
  - date range / withinDays / workoutID API를 deterministic dataset으로 매핑
  - shared snapshot fetch가 mock snapshot을 우선하도록 조정
- **Verification**:
  - unit test로 representative query APIs가 mock mode에서 기대값을 반환하는지 확인

### Step 3: Add runtime controls on iOS and visionOS

- **Files**: `DUNE/Presentation/Settings/SettingsView.swift`, `DUNEVision/App/DUNEVisionApp.swift`, `DUNEVision/App/VisionContentView.swift`, `DUNEVision/Presentation/**/Vision*MockData*.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - iOS Settings에 simulator-only mock data section 추가
  - seed/reset 액션과 현재 상태 표시 추가
  - visionOS utility sheet/panel 진입점 추가
  - visionOS app/service 구성이 mock mode 토글 후에도 새 데이터를 반영하도록 refresh 경로 정리
  - 새 UI copy를 string catalog에 반영
- **Verification**:
  - iOS UI smoke에서 section/button 존재 확인
  - visionOS는 manual verification으로 entry, seed, refresh, reset 확인

### Step 4: Regenerate project and run focused validation

- **Files**: `DUNE/DUNE.xcodeproj/project.pbxproj`, test files
- **Changes**:
  - 새 파일 반영을 위해 `scripts/lib/regen-project.sh` 실행
  - unit/UI smoke/vision build 검증
- **Verification**:
  - `scripts/test-unit.sh --ios-only`
  - `scripts/test-ui.sh --smoke`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' build`

## Edge Cases

| Case | Handling |
|------|----------|
| seed 버튼을 여러 번 눌렀을 때 record 중복 누적 | wipe-and-reseed로 매번 기존 mock-owned data 정리 후 재생성 |
| reset 후 mock query service가 여전히 데이터 반환 | persisted mock mode flag와 cache invalidation을 함께 처리 |
| visionOS simulator에서 HealthKit availability가 런타임마다 다름 | mock mode가 켜져 있으면 HealthKit availability보다 mock provider를 우선 |
| direct query service와 SwiftData seeded data 간 날짜/수치 불일치 | 공통 dataset builder 하나에서 snapshot/workout/vitals/body fixtures를 동시에 생성 |
| 실기기에서 debug UI가 노출될 위험 | compile-time + runtime simulator guard 이중 적용 |
| string localization 누락 | 새 copy는 `Localizable.xcstrings` en/ko/ja 동시 등록 |

## Testing Strategy

- Unit tests:
  - mock mode store / simulator guard
  - dataset builder outputs
  - query service fallback representative cases
  - seed/reset idempotence
- Integration tests:
  - `scripts/test-unit.sh --ios-only`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' build`
- Manual verification:
  - iOS simulator Settings에서 seed/reset 실행 후 Today/Activity/Wellness populated 상태 확인
  - visionOS simulator mock entry에서 seed/reset 실행 후 Today/Train window populated 상태 확인
- UI tests:
  - `scripts/test-ui.sh --smoke`로 Settings smoke 회귀 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| direct query consumer 누락으로 일부 detail 화면이 비어 있음 | medium | high | query service 단에서 mock mode fallback을 공통 처리 |
| mock dataset이 너무 커서 simulator 초기 렌더링이 느려짐 | medium | medium | deterministic 범위를 30~60일 수준으로 제한하고 계산은 lazy/query별 slicing 사용 |
| visionOS mock mode 토글 후 service가 재구성되지 않음 | medium | high | app/service를 mock-aware하게 만들고 refresh signal로 재로드 |
| reset이 실제 사용자 데이터까지 지울 위험 | low | high | simulator-only guard + mock-owned identifier/sourceDevice/pattern 기준 삭제 |
| localization/AXID 누락으로 UI test 또는 리뷰 finding 발생 | medium | medium | settings strings와 AXID를 같은 변경에 포함 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 mock/seed 자산과 simulator gating 선례가 있어 기반은 충분하다. 다만 visionOS 런타임 토글 반영과 direct query service 전반의 mock fallback 범위를 실제 코드에 안전하게 맞추는 작업이 넓어, 구현 중 일부 조정 가능성이 있다.
